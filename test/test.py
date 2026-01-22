import numpy as np

i_0 = 10
chunk_size = 10
timestep_arange = np.arange(start=i_0, stop=i_0 + chunk_size, step=1, dtype=np.int64)

t_0 = 0.1
environment_dt = 0.02  # Example time step value
time_delta = np.arange(chunk_size, dtype=np.float64) * environment_dt
timestamp = t_0 + time_delta  # shape=(chunk_size,)


print(f"Timestep array: {timestep_arange}")
print(f"timestamp array: {timestamp}")
