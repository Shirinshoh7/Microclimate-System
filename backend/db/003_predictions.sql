-- Таблица хранения прогнозов (predictions)
CREATE TABLE IF NOT EXISTS predictions (
    id            bigserial       PRIMARY KEY,
    device_id     uuid            NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    parameter_type varchar(10)    NOT NULL,
    predicted_value real          NOT NULL,
    prediction_ts  timestamptz    NOT NULL DEFAULT now(),
    target_ts      timestamptz    NOT NULL,
    horizon_minutes integer       NOT NULL,
    is_accurate    boolean,

    CONSTRAINT ck_pred_parameter CHECK (parameter_type IN ('temp', 'hum', 'co2', 'co')),
    CONSTRAINT ck_pred_horizon   CHECK (horizon_minutes > 0)
);

CREATE INDEX IF NOT EXISTS idx_predictions_device_target
    ON predictions(device_id, target_ts DESC);
