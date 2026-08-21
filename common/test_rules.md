when running tests, I hope that you can follow the rules

whether testing the NVT or NPT, we should have bot the rigid and flex tests. 
for rigid, there should be timestep scan of 0.5fs, 1.0fs, 2.0fs, 4.0fs, 6.0fs
and for flex, there should be timestep scan of 0.5fs, 1.0fs, 1.5fs, 2.0fs
so in total there should be 9 tests

when running smoke tests, just do 100ps, and when running serious tests, we should have in total 2ns of simulation, and for sampling we discard the first 20% of traj, then the left 1.6ns should give 20000 data points regardless of the integration timestep. so the sampling interval should be different for different timestep. 

and for flexible ones, tau_t should be 500fs and tau_p should be 1000fs.
for rigid ones, tau_t should be 1000fs and tau_p should be 2000fs

when doing tests, there should not be more than 16 tests running togther