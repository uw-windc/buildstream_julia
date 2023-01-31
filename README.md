2023, January 31

1. Created GitHub repository
2. Refactored and simplified codebase. Made everything a function.

2023, January 9

1. partitionbea.jl is accurate

2. calibrate.jl is accurate to 2 decimals, at 3 decimals something funky is happening. It seems to be concentrated on the :min variable. No idea why.

3. nationalmodel.jl is working and seeming accurate. This is using the data from calibrate.jl, so I'm guessing there are errors somewhere. On inspection, the gams model is restricted to 2010, which had no errors in calibrate. So that's cool. Checked 2011 and it's accurate to at least 3 decimals. This is visual inspection only. 

4. Cleaned up a lot of extraneous files. 


Still to do:

1. Add in the safety checks and display commands from GAMS.


2022, December 21

1. partitionbea.jl works and is accurate
2. calibrate.jl works, but it inaccurate. My objective function is slightly larger than the gams version and I can't determine why. It seems the jl file has one fewer constraints somewhere, and I can't figure out where or why.

To explore this further, check cal.txt which is the output from the cplex solver in GAMS. 