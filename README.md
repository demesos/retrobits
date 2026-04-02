# RetroBits  
A collection of small C64 games with source code.  

## About  
These are short games I wrote just for fun—sometimes to test ideas or experiment with new techniques.  

## Requirements  
To build the games, ensure the following tools are installed and available in your system's PATH:  
- **[cc65](https://cc65.github.io/)**: A complete cross-development package for 6502-based systems.  
- **[LAMAlib](https://github.com/demesos/LAMAlib)**: A library for handling common tasks in C64 game development.  
- **Python**: Needed for auxiliary scripts like `petscii2x.py`.  
- **Make**: For managing the build process.  

## The Games  

### Moonlander  
My take on the classic moon landing game. Written in Assembler. The objective is simple: land the lunar module ("The Eagle") softly on the designated site. The game is somewhat difficult. Gameplay confined to a single screen. This game was originally created in January 2024 for the *OneHourGameJam #454*. 

### Olympic Splashdown
In this game, we are going to relive the Olympics in Paris 2024, especially the swimming events on the Seine. During the games, there were a few issues with water quality, which inspired me to create this satirical game on the topic. Please note that this is a humorous approach, and I mean no offense to the citizens of Paris or anyone living along the Seine. This game was originally made in December 2025 for the *OneHourGameJam #556*. 

### The Sands of Time
You are in a one-hour class and must reach the upper half without being crushed by the sand or cornered in the lower half. The interesting aspect of this game is the sand physics. I have implemented a simple sand behavior based on three rules:

1. If there is space beneath a sand grain, it moves down one line.
2. If there's another sand grain below it but a free spot diagonally down either side, it moves there.
3. If there is a sliding character underneath it, the sand grain will try to move diagonally down if the path is clear.

This behavior implements what I refer to as “**Boulder Dash Physics**,” where rocks fall or tip over if two of them are stacked on top of each other, creating a material cone of **45°**. Since all movements occur downwards, we can avoid marking already moved grains or double buffering by simply processing updates from the lowest part of the screen upwards. This prevents a grain that falls down from falling again during the next line's processing, effectively transferring it immediately to the ground.