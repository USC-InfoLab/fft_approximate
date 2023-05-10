# fft_approximate

### About

fft_approximate is an open-source PostgreSQL extension that enables users to quickly answer aggregate range queries on time series data, using an approximate approach. Our approach leverages the power of Fast Fourier Transform (FFT) to store a condensed representation of each time series. By selectively storing only the top-k coefficients, we're able to compute aggregate range queries quickly and efficiently, with a small sacrifice on accuracy.

Users are encouranged to use this extension when working with large volumes of time series data but require rapid query processing times. With fft_approximate, you can achieve lightning-fast query performance while maintaining high accuracy, giving you a powerful tool for analyzing and visualizing time series data.

### Usage

```
-- create an extension
CREATE EXTENSION fft_approximate;

-- create a regular SQL table
CREATE TABLE intraday_activity (
  id BIGINT PRIMARY KEY,
  date_calories INT NOT NULL,
  calories DOUBLE PRECISION NOT NULL,
  mets INT NOT NULL,
  activity_level INT NOT NULL,
  timestamp DATE NOT NULL
);

-- create a table approximation
SELECT create_approximation('intraday_activity', 'calories');
```

```
-- query data
SELECT AVG_APROX(calories) 
FROM intraday_activity
WHERE timestamp < '01-01-2022' AND timestamp > '03-01-2022';
```




