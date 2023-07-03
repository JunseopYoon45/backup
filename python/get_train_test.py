def get_train_test(df, date_array, input_bucket, val_tp,
                   country='KR',
                   rm_outlier=True,
                   sensitivity=4,
                   process_method='interpolate',
                   interpolate_method='linear',
                   anchored_offset=None,
                   ):
    if rm_outlier:
        remove_outlier(df=df, sensitivity=sensitivity, col=val_tp)
        process_missing_values(
            df,
            process_method=process_method,
            interpolate_method=interpolate_method,
        )
    df = df.groupby('ds').sum()
    df_train = fill_missing_date(df=df, date_array=date_array, freq='D')
    df_future = get_future_dataframe(date_array=date_array[2:], country=country)
    df_all = pd.concat([df_train, df_future]).fillna(0)

    df_trend_factors = get_trend_factors(df_all.loc[:df_train.index.max()], df_all.copy(), val_tp)

    df_all = df_all.merge(
        right=df_trend_factors,
        left_index=True,
        right_index=True,
        how='left'
    )
    drop_unused_columns(df_all, val_tp)

    if anchored_offset is None:
        if input_bucket == 'W':
            anchored_offset = 'MON'
        else:
            anchored_offset = 'S'

    mean_cols = []
    sum_cols = df_all.columns.to_list()

    df_all_resampled = resample_df(
        df_all,
        freq=input_bucket,
        anchored_offset=anchored_offset,
        sum_cols=sum_cols,
        mean_cols=mean_cols
    )
    # Seasonal Index
    df_all_resampled['mm'] = df_all_resampled['ds'].dt.month
    df_all_resampled['quarter'] = df_all_resampled['ds'].dt.quarter
    df_all_resampled['season'] = df_all_resampled['mm'].apply(month_to_season)
    df_idx = df_all_resampled[df_all_resampled['ds'] <= date_array[1]]
    mean = df_idx.mean()['y']

    date_range = pd.date_range(start=df_all_resampled.index.min(), end=df_all_resampled.index.max(), freq='D')

    df_month_idx = df_idx.groupby('mm').mean()[['y']] / mean
    df_month_idx.rename(columns={'y': 'month_idx'}, inplace=True)
    df_season_idx = df_idx.groupby('season').mean()[['y']] / mean
    df_season_idx.rename(columns={'y': 'season_idx'}, inplace=True)
    df_quarter_idx = df_idx.groupby('quarter').mean()[['y']] / mean
    df_quarter_idx.rename(columns={'y': 'quarter_idx'}, inplace=True)

    df_all_resampled = df_all_resampled.merge(
        df_month_idx,
        how='inner',
        left_on='mm',
        right_index=True
    ).merge(
        df_season_idx,
        how='inner',
        left_on='season',
        right_index=True
    ).merge(
        df_quarter_idx,
        how='inner',
        left_on='quarter',
        right_index=True
    )
    df_all_resampled.sort_index(inplace=True)

    df_all_resampled.drop(columns=['ds', 'season', 'quarter', 'mm'], inplace=True)

    # Seasonal index
    # df_all_resampled.drop(columns=['ds'], inplace=True)
    df_all_resampled.index.name = 'ds'
    df_all_resampled.fillna(0, inplace=True)

    df_history = df_all_resampled.loc[:date_array[1]]
    df_future = df_all_resampled.loc[date_array[2]:]

    return df_history, df_future