# Formula 1 Car Physics
## Brake Migration
Brake migration is the shifting of brake bias rearwards as the driver releases the brake pedal. This shift allows the car to initally have a higher front brake bias percentage, which provides greater stopping power, then shifts the bias rearwards to prevent the front tyres from getting locked up.  

The equation below represents the total brake bias. Total brake bias is calculated by adding the base brake bias to the product of the ratio of brake pedal percentage and ramp level multiplied by the brake migration percentage.

```math
total = base + (pedal - ramp) / (1 - ramp) * bmig
``` 

#### Examples
##### Example 1
```ini
Setup:  
Base_Brake_Bias = 53.0%  
BMig = 2%  
Ramp = 40%

Scenario 1:  
Brake_Pedal = 60%  
Total_Brake_Bias = 54.0%  

Scenario 2:  
Brake_Pedal = 40%  
Total_Brake_Bias = 53.0%  
```

##### Example 2
```ini
Setup:  
Base_Brake_Bias = 54.0%  
BMig = 8%  
Ramp = 0%   

Scenario 1:  
Brake_Pedal = 75%  
Total_Brake_Bias = 60.0%  

Scenario 2:  
Brake_Pedal = 50%  
Total_Brake_Bias = 58.0%  
```

## Differential Settings
Differential adjustment allows for the driver to change the differential lock percentage for the three phases of a corner. Entry, Middle, and Exit/Highspeed. High speed corners share the Exit differential setting. 

Higher differential setting = more differential locking.  

```ini
Differential = 1/12
This represents a completely open differential.
Provides most stability and least acceleration/rotation.
```

```ini
Differential = 12/12
This represents a completely closed differential.
Provides least stability and most acceleration/rotation.
```
