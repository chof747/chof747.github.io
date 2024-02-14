---
layout: post
title:  "IR Reader for Smart Meter"
author: 
  - Christian
categories:  electronics home-assistant
toc: false
---

# Situation

I recently got a new Smart Reader from the local power distribution company [Wiener Netze](https://www.wienernetze.at/smartmeterwebportal). Wiener Netze offers the consumption data in 15 minute intervals but the smartreader is equipped with an IR interface which provides electricity consumption data in real time (once per second). And of course I could not resist the temptation to build something that could read the information and integbrate it into my home assistent setup. - But where to start?

Turns out that getting a smart meter infrared reader implemented in a way that it integrates into the other parts of my home automation concept involved a few parts and ended up as a nice challenge. Fortunately I could utilize tons of information and resources which are available thanks to the help of the open source and open hardware community. Foremost the following resources prooved very valuable:

- [Volkszähler](https://wiki.volkszaehler.org/start) - especially as the starting point for my IR Reader Hardware
- [Otello's Blog - Smartmeter auslesen](https://ottelo.jimdofree.com/stromz%C3%A4hler-auslesen-tasmota/) - as it was the critical step to understand the format and how to decode it
- [Tasmota Smartmeter Interface](https://tasmota.github.io/docs/Smart-Meter-Interface/#general-description) - which I used as the firmware to try out the reader and establish a first working version
- A lot of internet discussion, github issues from which I would like to mention especially [Landis+Gyr E450 auslesen: Wie ich es mache](https://www.photovoltaikforum.com/thread/137994-landis-gyr-e450-auslesen-wie-ich-es-mache/#google_vignette) which gave me the final hint how the messages should be interpreted thanks to the attached excel

But although the available documentation is quite comprehensive and many people have solved the problem for their setup and implemented it in different frameworks and programming languages, there were still enough pieces of the puzzle left to be solved by me to implement it in the way I need it working fir my setup. And at the end the challange included:

- Designing and assembling 2 PCBs including proper cases
- Establishing proper power supply in the switchbox outside of my appartement that contains the meter
- Implementing my first esphome external component 
- Interpreting the binary messages sent by the smart meter
- Identifying and implementing the right CRC method to ensure the integrity of the received information

but first things first, let's start with the ...

# Idea

## Requirements 

Having a smartmeter installed, of course I wanted to use the possibility to read out the data directly and integrate it into my home automation solution. First as a new sensor to obtain the information, integrate it into my dashboards and monitor my power consumption with all the other parameters of my home. And second also as a possibility to utilize the data in  real time for some data mining and analysis (but more on that in a different blog).

## Concept

As I am using Home Assistant as my home automation platform and espHome as the framework to implement the firmware of my ESP based IoT sensors and actuators the basic idea of course was to setup a new gadget (e.g. an ESP32 or ESP8266 based thingy) which would interface with the smartmeter and report the data back to Home assistant (see schematic below). As I have already a sensor data logging process implemented (via NodeRed and influxdb) this was also easily integrated for the smartmeter.

![Architecture of Smartmeter Solution](/assets/images/power-reader/architecture.png){:class="img-explain"}

The network communication between the reading device and Homeassitant as well as the Mqtt broker should be done via secured WiFi, while HomeAssistant, Mqtt broker, node-red and influxdb are already connected using wired LAN. 

In HomeAssistant the idea is to display on my main dashboard the current power consumption and to use the Energy functionality of HomeAssistant for long term tracking, comparison of differemt days and alike. Further use cases will be explored later, for this project just this would be enough.

# Components

The solution consists of an IR read header that is attached to the smartmeter and an ESP8266 board which connects to the IR reader via UART and receives, decrypts and parses the messages sent by the smartmeter.

## IR Reader

### Circuit Board

I basically reproduced the [TTL reader design from volkszaehler.org](https://wiki.volkszaehler.org/hardware/controllers/ir-schreib-lesekopf-ttl-ausgang) in KiCad 7 and changed a view things:

- Replaced 13k resistors by 10k (as I have a lot of them in stock)
- Added an RJ11 connector with 4 pins as a connector to the microcontroller unit to give the final result a more professional look (as it will be placed outside my appartment)

But besides that I kept the basic schematic and shape of the original design:

![Board Layout](/assets/images/power-reader/smartmeter-ir-reader-brd.svg)

You can find all the necessary [KiCad files on Github](https://github.com/chof747/smartmeter-ir-reader/tree/main).

**Fabrication Note**: I had the boards produced by JLC PCB but I am not recommending here any Fab-House (to admit I never tried out one of the others). Completing the design and having functional boards in my hands required *"only"* two iterations. First I messed up the pin layout for the RJ11 connector, and second I mixed up the pads for the two transistors in the schematic. (Yes, you should always look twice, and printing the pcb layout on paper and testing the footprints also helps.)

### IR Reader Case
Regarding the case I also oriented myself on the 3d designs which are 
[available on thingiverse](https://github.com/chof747/smartmeter-ir-reader/tree/main). Of course I had to adjust them to the different connector and also to the exact dimensions of my smart meter. If you look on the picture below you will find that I designed a proper housing for the RJ11 socket which makes the handle of the pan-like structure a bit bigger and I also increased the base of the housing to make it fit exactly to the circular inset on the front of my meter where the reader should attach to.

![IR Reader Housing](/assets/images/power-reader/smartmeter-reader-case.png)

The reader will be attached to the smartmeter as depicted below. The case has 4 magnets on the bottom but it seems that the weight of the device is too heavy to firmly attach it to the meter. I therefore added some bluetack and it solved the issue (keeping my Duct Tape in reserve if this would).

![Assembly](/assets/images/power-reader/smartmeter-assembled.jpg)

One word to the RJ11 connectors, I added them to create a more professional look of the connection between the parts, however it they come in really handy for any type of 4 or 6 wire connections, as the single elements of the connections (the plugs, the sockets as well as the cables) are easily available and with the correct crimping tool, confectioning the cables is extremely simple and reliable. Plus you get a very tight connection that not only looks good but is also much more sustainable than e.g. Dupont connectors.

## Microcontroller Unit

### Circuit Boards

For the microcontroller I am using an ESP8266 on a Wemos-D1 Mini board. I have always a set of them in my drawers, as they are at the moment my favourite microcontrollers. As I planned to put it on the switchboard outside of my appartment I did not want to put there more parts than necessary. Therefore I created, also for other purposes a carrier PCB for the D1 Mini which also features a 5V power supply and breaks out the pins of the D1 Mini so that HATs can be put on it as well ([Wemos Mains Devboard](https://github.com/chof747/wemos-mains-dev)).

In order to connect the two components together I also designed a [HAT containg two RJ11 sockets](https://github.com/chof747/rj11-wemos-hat) that provide power and ground plus two data lines which can be connected with bodge wire to particular GPIO pins increase the reuse of the board. Furthermore the sockets can be driven by either 3.3V logic voltage or the 5V power provided by the power supply.

![RJ11-Hat](/assets/images/power-reader/rj11-hat.png){:class="img-original"}

### Microcontroller Case

The main board with the D1 Mini and the Hat are stacked on top of each other and put into the same caae in a way, that there are openings in the case for both RJ11 sockets and the plugable screw terminal on the main board which receives the power. The case is designed in a way that the bottom plate and the housing are screwed together with 4 m3 screws and m3 brass insertion nuts. Also the main pcb is screwed on the bottom plate of the case with m3 screws and insertion nuts. The case also has a little roof like structure over the plugable screw terminal to safely cover the screws of the plug so that no mains voltage is exposed. 

**TODO:** Picture of the case from Fusion360

## Overall Assembly

Putting this all together in the switch box outside of my appartment took a few more steps:

1. Establishing mains power supply from behind my meter in the switch box
2. Finding a proper place for the main device (containing the micro controller)
3. Connecting the microcontroller board to the reader attached to the smart meter

For the first step I asked of course an expert to find a proper solution, as playing around with Mains installation is nothing to mess around with easily. So the final solution was to use a spare circuit breaker in the switch box inside my appartement and root a cable in a spare channel back to the switchbox outside. By this I have a clean power line which is properly protected with an earth leackage trip and a circuit breaker and it can be switched on and off from within the appartment. 

**Note:** Having everything properly installed turned out very important during tuning the setup, as I produced a significant short, which luckily was covered by all the implemented safety measures and did not cause any damage beyond the circuit board itself. So please do not tinker around with mains, if you do not know what to do!

# Firmware

When it comes to firmware, you have several options:

- [Volkszaehler.org](https://volkszaehler.org/) offers also a full software stack including middleware and frontend <br/>
(*I have not checked that in detail*)
- [Tasmota](https://www.tasmota.info/) as mentioned already offers a [Smartmeter Interface](https://tasmota.github.io/docs/Smart-Meter-Interface/#general-description) which is extremely elaborated and offers very flexible solutions<br/>
*I used this solution as firmware to try out the reader and establish a first working version*
- There are tons of smaller projects besides the one I mentioned in the beginning which gave me concrete hints to solve the issues I was facing, there are a lot of other projects like that of [Alexander Pohl](https://github.com/ahpohl/smartmeter) for example

However as mentioned already, I have my home automation solution built on HomeAssistant and ESPHome, so naturally I was looking for a solution that was based on an ESPHome firmware and was able to read the smart meter messages from my particular smart meter. And this involved several steps:

1. Understanding the format of the data telegrams
2. Decrypting the content which contains the data of the meter
3. Parsing the decrypted telegram
4. Implement a proper CRC checking to ensure data integrity of the transmitted data
5. Wrapping everything into an ESPHome component and its sensors 

# Setting up the Meter

- follow the instructions here https://www.wienernetze.at/kundenschnittstelle2
- Smartmeter customer interface https://smartmeter-web.wienernetze.at/#/anlagedaten^
- esphome materials
- Consider tasmota functionality
- [esphome component](https://github.com/bernikr/esphome-wienernetze-im150-smartmeter)
- [sketch for Landyr](https://github.com/aldadic/esp-smartmeter-reader/blob/main/esp-smartmeter-reader/esp-smartmeter-reader.ino)