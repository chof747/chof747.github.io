---
layout: post
title:  "Tram Arrival Monitor"
categories: electronics home-assistant
---
# Problem: Is it the right time to leave to catch the next tram?

When I want to catch a tram to go to work, or I want to get a ride into the city for dinner or to meet friends, it sometimes happens to me that I just miss it when I arrive at the station, 2 minutes from my home. Or sometimes I hear it already coming along the street and have to start sprinting in order to catch it - which is not always guaranteed. And recently the trams in Vienna had to extend the interval quite a bit, at least in my area, which adds to the annoyance, when you have to wait 15 minutes for the next one. 15 Minutes I could have used more effectively at home for example for writing a new blog post. And yes of course there is [an app](https://www.wienerlinien.at/web/wl-en/wienmobil-app) to check when the next tram is coming , but sometimes picking out the phone when I have already packed it into my bag, opening the app, selecting the station can be a bit annoying.

And hey, [Vienna's public transportation service](https://www.wienerlinien.at/web/wl-en) has a real time API and a few month ago I forked an [already existing Home Assistant integration](https://github.com/custom-components/wienerlinien) and created [my own version](https://github.com/chof747/wienerlinien) which is showing the time of the next departure on my Home Assistant Dashboard with some nice icons. But unfortunately I only have my home assistant dashboard available on the phone (yet). So no real gain so far. 

So how to solve this issue and have some fun creating the solution?

{:toc}

# Idea: Make my own tram monitor device 

Wouldn't it be useful to have a little device or indicator right there where I need it: At my appartment's door, next to the wardrobe? By this  I can check easily how much time I have to catch the tram when I make myself ready to leave the appartment. If it turns out I would miss it or I just missed it, I can take it easy or better hurry because I have a realistic chance to catch it just in time.

## Requirements

1. Simple display indicating the time I have (in real time)
2. Small enough to stick it to the wall next to my wardrobe without a huge footprint
3. Giving me a direct indication if the tram is catchable or not, including also the time it takes to leave the house and go/run to the station
4. Able to turn the display off when I do not need it (e.g. at night to reduce the light noise in the appartment)

## Solution Design

As it happens I have recently designed and ordered a breakout board to test RGB leds as a status bar. You can find the schematic and PCB files on my GitHub under [led-status-bar](https://github.com/chof747/led-status-bar). And with 5 RGB leds it should be possible to indicate the status of the next tram arrival including some timing features in the following way:

![LED Bar Status colors](/assets/images/status-lights_tram-monitor.png){:class="img-explain"}

And having the status of the tram station already as a sensor in home assistant I can put all of it together via a Wemos D1 Mini which is polling the data from home assistant, interpreting the time of the next arrival and translating it into the proper color code of the status bar.

In the final version I also added a push button to the device to be able to check the status on request and not having the lights on all the time, which can be a bit annyoing, especially at night and also saves a few mW when nobody is looking on it:

![Wemos D1 Mini based prototype](/assets/images/wemos-prototype_tram-monitor.jpg)

# Implementation

## Hardware 

### Assembly

The device is simple put together with a few components. You need 

- A Wemos D1 Mini
- An assembled LED-Status board 
- A Push button

Assemble them according to the following diagram:

![Tram Monitor Connection Diagram](/assets/images/connection-sketch_tram-monitor.jpg)

| Wemos D1 Mini Pin | Led Bar Pin | Push Button Pin |
|-------------------|-------------|-----------------|
| 5V                | Pin 1 (VDD) | -               |
| G                 | Pin 4 (G[ND]) | Pin 1         |
| D3                | -           | Pin 2           |
| 3V3               | Pin 3 (VREF)| -               | 
| D7                | Pin 2 (DTA) | -               |

### Case

In my case I decided to fix the device partly behind a mirror in my wardrobe, where I can easily see it when I leave the house. Therefore I could design a rather simple case which is only partially covering the parts. 

[Case on Thingiverse](https://www.thingiverse.com/thing:6221347)

## Firmware

As I have the tram data already available in Home Assistant, and I use espHome in general for all my IoT devices that communicate with Home Assistant, I also configured and programmed the firmware for the Tram Monitor in esphome.

The firmware consists of two files:

1. The esphome YAML comfiguration file (firmware_trammonitor.yaml)
2. A C++ header file containing the more complex code to parse the time string of the sensor and translate it into the led colors as well as some functions to turn on/off the monitor in total (trammonitor.h)

I have assembled the two files with some placeholders to be replaced by you in a [gist](https://gist.github.com/chof747/6c119cb13d116dd88252a0d8d22c73e8). Below you can find the specific code blocks explained ...


### General Architecture:

The device is designed in a way to directly consume the state of the next tram departure together with some configuration values (i.e. the time tresholds and if the display is on or off) from home assistant via the built in home assistant API. By this the user is able to configure the thresholds in his home assistant instance and is also able to turn the display on or off via home assistant (and thus would be able to utilize automations).

The hardware components are implemented and configured via the ESPHome YAML comfiguration. The logic to drive the LEDs based on the departure time is in the c++ header file in a set of functions that are encapsulated under a specific namespace:

```
chof::trammonitor
```

This allows to call the functions directly from the YAML configuration e.g.:

```yaml
... 
    on_value: 
      then:
        - lambda: 'chof::trammonitor::setNextDepartureTime(x.c_str());'
```

For me, this approach is a convenient way to keep complex logic out of the YAML configuration and keep the ESPHome device file readable.

I also opted to store the state values of the device not in global variables in the YAML configuration but in static variables within the namespace `chof::trammonitor`. One could argue to use a class for this but it works by this as well for this specific purpose.

#### ESPHome configuration:

- **Tram Departure Time Sensor**: [Home Assistant text sensor](https://esphome.io/components/text_sensor/homeassistant)
- **RGB Led Bar**: [NeoPixelBus light](https://esphome.io/components/text_sensor/homeassistant)
- **Real Time**: [Home Assistant Time Source](https://esphome.io/components/time/homeassistant)
- **Time thresholds**: Implemented as [Home Assistant Sensors](https://esphome.io/components/sensor/homeassistant) for the waiting (blue), walking (green) and running (yellow) time respectively 
- **On/Off**: [Template Switch](https://esphome.io/components/switch/template) to be able to turn the display of the tram status on site or remotely on or off
- **Button**: a [Binary Sensor/GPIO Pin](https://esphome.io/components/binary_sensor/gpio) that detets the button press and at the moment just triggers the state template switch above

#### C++ code structure:

The c++ code contains the following functions which are called from the YAML configuration:

- **`setNextDepartureTime(const char *tstr)`**: Translates the timestring from the sensor into a unix timestamp for further processing
- **`updateTramStatus()`**: Is evaluating the time until the next departure and determining the overall state 
- **`getTramStatusColor()`**: Provides the LED color for the current status
- **`getLedNumber()`**: Provides the number of LEDs that should be shown based on the time remaining for the status
- **`updateBar()`**: Updates the LEDs on the status bar according to the status color and number of leds that need to be displayed
- **`silenceBar():`**: Turns off all lights and resets the status to `none`

### Key features explained

#### Obtaining the seconds until the next tram

The next departure time sensor from Home Assistant provides the next departure time in the following format

```
2023-09-17T22:27:35.000+02:00
YYYY-MM-DDTHH:MM:SS.sss+TZ
```

which needs to be transformed into a unix timestamp to get the timestamp of the next departure. This is done in the C++ header file in the function `setNextDepartureTime(const char* tstr)`:

This function parses the time with `sscanf` into the components of a time structure according to the format described above and then maps the year and month to the correct values as `mktime` needs it (year starting from 1900 and month starting with 0):

```cpp
tm tc;
sscanf(tstr, "%d-%d-%dT%d:%d:%d",
        &tc.tm_year,
        &tc.tm_mon,
        &tc.tm_mday,
        &tc.tm_hour,
        &tc.tm_min,
        &tc.tm_sec);
tc.tm_year -= 1900;
tc.tm_mon -= 1;
```

The timestamp of the next departure is then calculated via passing the time structure to `mktime` and assigning it to the static variable in the same namspace `nextDepartureTime`:

```cpp
nextDeparture = mktime(&tc);
```

#### Driving the LED Status bar:

It took some research on the [ESPHome API documentation](https://esphome.io/api/index.html) to figure out how the NeoPixelBus can be driven out of c++ code without the need to configure the single leds in the YAML declaration.

The trick is to obtain an instance of a `esphome::light::AddressableLight` from the id that you give the NeoPixelBus in the YAML configuration. In the firmware of the trammonitor this works as follows:

**YAML Configuration**:
```yaml

light:
  - platform: neopixelbus
    ...
    id: tramLights
```

**C++ Header File**:
```cpp
esphome::light::AddressableLight *bar =
          (esphome::light::AddressableLight *)id(tramLights).get_output();
```
**Note**: The object you need to drive the leds is returned by the `get_output()` function of the instance returned by the id.

You can then address single lights by the proper index and assign distinct colors (multiplied with an overall brightness from 1 ... 255), or assign all of them at once with the `all()` method:

```cpp
// Addressing single LEDs:
(*bar)[i] = chof::trammonitor::getTramStatusColor() * 80;

// Addressing all LEDs:
bar->all() = esphome::Color::BLACK;
```

#### Identifying the Status

To keep the solution flexible I use numeric helpers in home assistant to configure the transition between the various states (as depicted in the first diagram above). Those helpers have the id's:

- **input_number.tram_waiting_time**: The time (minuntes) until the led bar is showing blue lights
- **input_number.tram_walking_time**: The time (minuntes) until the led bar is showing green lights
- **input_number.tram_running_time**: The time (minuntes) until the led bar is showing yellow lights

If the time to the next departure is below the runnning time it is too late to leave the appartment and the device is showing all leds in red.

In the code this is done in the `updateTramStatus()` function as follows:

Four C-macros are defining the seconds to the next tram, and the threshold in seconds for each of the three status transitions:

```cpp
#define secondsToNextTram() (nextDeparture - id(haTime).now().timestamp)
#define blueTime() (int)(id(haTramBlueTime).state * 60)
#define greenTime() (int)(id(haTramGreenTime).state * 60)
#define yellowTime() (int)(id(haTramYellowTime).state * 60)
```

And then the function checks for each status, starting with blue, if the time to the next tram is above the threshold and if the status is not the respective state. If this is true, the state is changed:

```cpp

int diff = secondsToNextTram();

...

if (blueTime() <= diff)
{
  if (tramstatus != tramstatus_t::blue)
  {
    tramstatus = tramstatus_t::blue;
    ESP_LOGI("trammonitor", "Tram is too far away");
  }
}
```

At the end the function checks if the state has to be changd and returns `true` if it has or `false` otherwise.

#### Determining the number of leds that should be turned on

After setting the status the firmware is also checking how much of the leds should be turned on in the respective color. This is true for the blue, green and yellow state and is determined by the interval between the threshold from the previous state to the threshold of the next state:

1. Blue

Get the time until the trigger for the transition from blue to green (`blueTime()`) is happening in minnutes and light up as many LEDs in blue as there are minutes left (if there are more than 5 of course all 5 will be on)

```cpp
int minutes = (int)ceil((secondsToNextTram() - blueTime()) / 60.0);
...
return (5 <= minutes) ? 5 : minutes;

```

2. Green and Yellow:

Here the number of leds is determined in relation to the overall phase time so that 5 leds are lighting up between 100%-80% of the time of the phase remaining and 1 when its less than 20%:

```cpp
float seconds = secondsToNextTram() - yellowTime();
float phasetime = greenTime() - yellowTime();
...
return (int)ceil(5.0 * seconds / phasetime);

```

# Installation

As described before, I decided to install the tram monitor next to the mirror in my wardrobe, so that I can get the information while dressing up to leave the house. The case I printed for this was designed in a way to hide the wiring and the microcontroller behind the mirror while providing the leds and a button in a nice box (see below)

Therefore I clued the Wemos D1 Mini to the flat part of the case, soldered on the wires (not my best job to be honest but it works) and installed it behind the mirror on the wall with strong adhesive tape:

![Tram Monitor assembly](/assets/images/tram-monitor/assembly/assembly.jpg)

The final result at the end does not look that bad:

![Tram Monitor final](/assets/images/tram-monitor/assembly/final.jpg)

# Conclusion

One of those home automation projects that originates from the fact that I had lying some prototyping boards around and wanted to use them to do something useful. And one that could be modified in many ways and adjusted to ones needs.

The building time is hard to judge (as I did it parallel to work and had some travelling in between) but I would guess it can be easily done in a weekend if you have the parts and the board ready. 

# Useful Links:

- [Wiener Linien Home Assistant Integration ](https://github.com/chof747/wienerlinien) (my fork)
- [RGB Led Status board](https://github.com/chof747/led-status-bar)
- [Gist with firmware files](https://gist.github.com/chof747/6c119cb13d116dd88252a0d8d22c73e8)
- [Case](https://www.thingiverse.com/thing:6221347)