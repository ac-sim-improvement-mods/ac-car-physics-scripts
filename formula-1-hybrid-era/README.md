# Formula 1 Car Physics
## Brake Migration
Brake migration is an adjustable setting that allows the brake bias to shift rearwards as the driver releases the brake pedal.  
While the car is traveling at high speeds and has a high load of downforce on the front wing, a higher front brake bias percentage will help decelerate the car quicker. However, a high front brake bias percentage will also lead to locking the front tyres up as the car loses speed/frontal downforce. Brake migration allows for the inital braking phase to utilize a higher brake bias percentage, then as the driver bleeds off the brake pedal, shift the brake bias rearwards to prevent front tyre lockups and aid in car rotation.

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

#### External references to help understand Brake Migration
- Video: [Mercedes engineer quickly explaining BMIG](https://youtu.be/ODaPkCehkkA?t=211)

## Differential Settings
Differential adjustment allows for the driver to change the differential lock percentage for the three phases of a corner; Entry, Middle, and Exit/Highspeed. High speed corners and corner Exit share the same differential setting. 

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

#### External references to help understand Differential Settings
- Video: [Chain Bear Differential video](https://www.youtube.com/watch?v=jbPZauD4DQM)  
- Video: [Daniel Riccardo Onboard Settings Adjustment](https://www.youtube.com/watch?v=UW6f7CkQ90U)  
- Video: [WTF1 Short Differential Explaination](https://youtu.be/JbqEtApATZg?t=242)
- Webpage: [Technical F1 Dictionary Differential](https://www.formula1-dictionary.net/differential.html)
