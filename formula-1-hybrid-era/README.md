# Formula 1 Car Physics
## Brake Migration
You have your base brake bias that you are familiar with setting in AC, known as Brake Bias. With the introduction of brake migration, there is now a “total brake bias”. The total brake bias represented by the following equation.

##### TOTAL BRAKE BIAS
```math
total = base + (pedal - ramp) / (1 - ramp) * bmig
``` 

#### Example
```math
Setup 1:  
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
```math
Setup 2:
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

BMig takes advantage of the high frontal downforce while at speed by increasing from the base brake bias. Since the front wheels have a lot of force pushing them into the track, the higher brake bias will result in increased stopping power. As the car slows down, the driver will begin to release the brake pedal. The brake bias will then, begin to shift rearwards, helping prevent the wheels locking due to the reduced frontal downforce. 

## Differential
Differential adjustment allows for the driver to change the differential lock percentage for the three phases of a corner. Entry, Middle, and Exit/Highspeed. High speed corners share the Exit differential setting. 

Higher setting, means more differential locking. 

Setting 1 for Entry would give the most stability and least amount of rotation. and 12 would be the least stable, and the most rotation. 

Setting 1 would give you the most traction and least acceleration for MID and EXIT, while 12 would give the least traction and most acceleration. 

Setting 1 = 0% locking (Open Diff)
Setting 12 = 100% locking (Closed Diff)