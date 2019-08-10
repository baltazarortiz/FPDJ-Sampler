# FPDJ_Sampler
Sampler component of 6.111 (Introductory Digital Systems Laboratory) final team project.
Notes adapted from project writeup.

## Block Diagram

![Sampler](/doc/sampler.png)

## Overview
The Sampler consists of a Sample Controller, a Storage Controller, and a Playback module.
The Sample Controller and Storage Controller were fully functional by the end of the
project, but the Playback module suffered from a few bugs that prevented correct audio
output. However, these should be easily correctable to achieve full functionality.

The Sampler nominally runs at 100MHz. However, the SD card runs at 25MHz, and the DDR
RAM runs at 200MHz. Theoretically, the Sampler’s core modules should be fine running at
200MHz as well, but this was not tested.

The block diagram omits a few top level wires that were used for
debugging, and has explicit widths for some busses that were parameterized, showing the
values used in the final version of the design.

## Storage Controller
The storage controller provides an interface between the SD card and the RAM. The storage
controller turned out to be the most complex part of the Sampler, and was split into two
sub-modules to organize its functionality.

### SD Interface
The first module that makes up the storage controller is the SD Interface. It interfaces with
the Nexys 4 SD interface provided by the course staff, and adds a FSM that allows the
FPGA to read SD cards that have been prepared with a Python script. The Python script
extracts the samples from the WAV files (skipping the headers for simplicity) and inserts
“magic words” (0xDEADBEEF, 0xCAFED00D, and 0xFEE1DEAD) as separators
corresponding to the beginning and end of each audio file as well as end of the data loaded
on the SD.

The SD Interface FSM starts a read once the FPGA is powered on and the SD card is ready,
then continues to start 512 byte reads until the end of the written data is reached. The SD
Interface receives the number of requests currently stored in the Arbiter, the second
module of the Storage Controller, and if there is not space for another full 512 byte read,
the FSM waits until some requests have been processed before starting another read. The
version of the FSM used for the final checkoff of the project stays in a “done” state after
loading and never needed to write to the SD card, but the FSM can easily be altered to go
back to the ready state to trigger more than one load in future versions. In addition, the
FSM could be easily expanded to support writing data back to the SD card.

The SD Interface buffers the bytes it receives and passes them to the Arbiter in 16 bit
chunks. In addition, it signals when the first bytes of a new file are being sent to the Arbiter.

The largest challenge in implementing the SD Interface was that it runs at 25 MHz, while the
rest of the FPDJ system runs at 100-200MHz. This was mainly an issue because it was a
detail that was forgotten until hardware testing started, but it was fairly easy to handle.

## Arbiter
The Arbiter acts as an interface to the DDR RAM. In the current design, it is connected to
the SD Interface and the Playback module, but it could be easily generalized into a port
system that would allow it to be quickly connected to a recording module or other modules
that need RAM access.

The Arbiter consists of a FIFO IP core and two FSMs. The FIFO is configured as a First Word
Fall Through FIFO for performance, but the design works with a standard FIFO as well. In
addition, the FIFO was configured with a depth of 1024 just in case the SD card outputs two
full 512 byte reads without any of the incoming data being written to the RAM, but in
practice, because the SD card is only running at 25MHz while the Arbiter runs at 100MHz,

The Arbiter receives “requests” from the SD Interface and Playback modules, which need to
write to and read from the RAM, respectively. Requests are 33 bits wide and have the
following structure:

* bits 31:30 - READ or WRITE (10 or 11)
  * Read requests:
    * Bits 30:27 - request ID number (described in Playback module
section)
    * Bits 26:0 - RAM address
  * Write requests:
    * Bit 30 - new file (1 or 0)
    * Bits 29:16 - unused
    * Bits 15:0 - data to write
        
The first FSM in the Arbiter is the Request FSM. When the SD Interface or Playback module
assert their “incoming request” wire, the Request FSM adds the request to the FIFO. If both
modules assert a request at once, it adds them one at a time. The Request FSM also contains
internal registers to ensure that it only adds one register per assertion of the incoming
request wires. This prevents duplicate requests being added due to the requesting modules
having different clock speeds than the Arbiter (for example, the SD Interface, which runs at
25MHz, while the Arbiter runs at 100MHz) and therefore asserting a “one cycle” signal for
much longer than one clock cycle inside the Arbiter. This design strategy turned out to be
very useful in ensuring that actions that were only supposed to happen once did in fact
only occur once, as unexpected signal hold times can occur from FSM transition time in
addition to different clock domains.

The second FSM is the RAM FSM. It idles until the FIFO contains at least one request, then
reads a request and either reads from or writes to the RAM based on the request type. To
do this, the FSM sends signals to the Ram2Ddr component provided by Digilent, which
creates a standard SRAM interface for communicating with the DDR. The RAM FSM holds
the RAM control wires at the correct values for long enough to meet the timing
specifications of the DDR, then moves on to the next request. Based on the type of request,
the RAM FSM also outputs whether it is writing a new file along with the address it has just11
written to or the request ID number of the sample it has just read from RAM, and these
pieces of information are sent to the Sample Controller and Playback Module, respectively.
Because the Nexys 4 has more than enough space to store 15 audio files, the RAM FSM
simply starts at RAM address zero and increments upwards. However, this would be
straightforward to change if more complex memory organization was needed.

The Arbiter took a lot of planning to design. The two FSMs were initially combined, but this
resulted in incoming requests being missed if the Arbiter was currently holding the RAM
control wires for a read or write. After the FSMs were separated, care had to be taken to
ensure that the Request FSM was the only one adding data to the FIFO and the RAM FSM
was the only one reading data out of the FIFO so that multiple driver errors did not occur.
In addition, once it was noted that the SD card runs at 25MHz, the registers had to be added
to the Request FSM to prevent duplicate requests being added.
Simulating and hardware testing both the SD Interface and Arbiter was also difficult.
Simulating required figuring out how to read data files into the testbench, which was not
very clearly documented. Hardware testing was a challenge even with an ILA module because of
the number of signals that needed to be tracked, which significantly increased
implementation time, and because the RAM does not provide any sort of acknowledgement
of a successful write, so testing did not really occur until the Playback module was also
implemented. In retrospect, it would have been a much better idea to create a simple top simulation
level to verify each part of the storage controller in the hardware before the entire Sampler
was complete.

## Sample Controller
The sample controller translates input from the Sequencer (another teammate's component) into memory addresses that are
sent to the playback module.

As described above, when the SD card detects it is reading a new file, it sends a signal to the
Arbiter, which then signals and outputs the RAM address when it actually writes the
beginning of the new file. The Sample Controller stores the incoming addresses in an array
of 15 registers and maintains a pointer for which register to update next. The pointer
wraps around from the last to the first register so that registers will be overwritten if more
than 15 samples are loaded. Similarly to the Arbiter, the Sample Controller uses an “already
updated” flag to prevent duplicate addresses being stored to mitigate issues with longer
than expected input signals.

When the Sequencer sends a nonzero trigger number to the Sample Controller, it sends the
starting address stored in the register with the trigger number to the Playback module.

The Sample Controller was the simplest module to implement. Due to its simplicity, the
Sample Controller can be easily parameterized in the future to support more than 15
samples at once.

## Playback
The Playback module handles reading samples from the RAM and mixing their sound data
together to create the final audio output for the Sampler. While the Playback module was
not completely functional for the project checkoff, the architecture is fully in place to play
multiple audio files at once after a few bugs are fixed.

The Playback module is organized into a number of playback “slots.” The current design
was implemented with 30 playback slots, though the theoretical maximum is somewhere
around 100 depending on how timing actually works out on the hardware and between
modules (23 microseconds in between each 44.1kHz sample clock pulse divided by 210
nanoseconds minimum DDR read time according to the Digilent Ram2Ddr spec).

Each slot consists of a RAM address, a data buffer, and two flags to track whether the slot
has generated a RAM request in the current sample clock cycle and whether it has received
data back from the RAM in the current sample clock cycle. In addition, the Playback module
has three registers to prevent issues arising from longer than expected input signal lengths,
just as the Arbiter and Sample Controller do.

When the Playback module gets a starting address from the Sample Controller, it loads the
address plus two (to avoid the first two start of file magic word bytes) into the next
available slot using a pointer that wraps around so that the oldest slots are replaced first. A
potential improvement to this mechanism would be tracking which slots are empty so that
old but still playing slots are skipped in favor of jumping to a newer, empty slot.

At each pulse of the 44.1kHz sample clock, the Playback module begins to look at one slot
per clock cycle. If the current slot is at the end of the file, it is cleared. Otherwise, if the slot
is not empty and the current slot has not yet received data during this sample clock cycle,
the Playback module generates a playback request which is sent to the Arbiter. As
described in the request structure, each playback request includes an ID which
corresponds to the number of the slot generating the request. When a request is generated,
the address stored in the slot is updated for the next sample clock cycle.

When the Arbiter signals that there is data ready from the RAM, it also provides the ID that
was in the request that retrieved the available data. Using the ID, the Playback module
updates the corresponding slot’s flags and shifts the new data into the corresponding slot’s
buffer. While shifting the data into the buffer, the Playback module switches the order of
the two bytes so that they are read in the correct order for actual audio output, as WAV
files store their samples in little endian format.

As data is shifted into the corresponding slot’s buffer, the data that is being shifted out is
added to a register that stores the overall audio mix for the current sample clock cycle. The
audio being added to the mix register is shifted to prevent clipping. At each pulse of the
sample clock, the contents of the mix register are sent to the overall audio output of the
playback module, and the cycle begins again for the next set of audio samples.

The Playback module turned out to be significantly more complicated than expected, and
was difficult to debug in hardware as it also relied on the full functionality of the Sample
Controller and Storage Controller. Similarly, simulating it either required a slow simulation
including both of the other modules, or faking the input data, which does not always
provide an accurate model of timing between the modules.

While the architecture for the Playback module appeared to work in simulation, there
seemed to be some bugs that were not debugged in time for checkoff. The main issues of
unintelligible playback despite seemingly correct output when debugging using an ILA module that appeared during checkoff
were caused by forgetting to switch the byte order to account for the little-endianness of
WAV files. In addition, the wrong bits were not passed to the PWM and the PWM was not
biased correctly, but that would not have fixed the byte ordering issue. Even when the
PWM and byte ordering were fixed after checkoff, the audio output, while clear, occured at
half the expected speed (with a corresponding lowering in pitch). This is most likely due to
a miswiring somewhere higher up, but nothing obvious was found. There also appears to
be a bug when triggering multiple samples in a row on hardware, although this bug does
not appear at all in simulation. Finally, shifting the data being added to the mix was not
implemented until after checkoff, but as the overall audio output was not functional then,
trying to mix samples without shifting was not fully tested on the hardware. Despite these
issues, the Playback module seems to be close to functional, and once fixed in the future,
will allow the Sampler to be fully functional.

The Playback module would also benefit from future restructuring, as some of the flags it
uses may be redundant, and it contains nested if statements that should be optimized. In
addition, Vivado seemed to be unable to implement the slot registers as BRAM as expected,
and used separate registers for each slot instead. The reason for this was not particularly
clear, but other fixes may resolve this as a side effect.

## Sampler Conclusion
Although the audio output was not fully functional by the time of checkoff, designing the
Sampler was a very rewarding process. The most interesting parts of the design were
working with components in multiple clock domains and creating an inter-module
communication system that can be generalized to other designs using the DDR RAM in the
future. Making sure that signed values for audio data were correctly propogated through
the design also required some extra attention to detail. In addition, learning how to write
testbenches that read datafile and looked at internal uut signals was a good learning
experience, and figuring out how to use Verilog header files was also useful.

The design process would probably have been smoother if each component had been
tested on the hardware after it was simulated, rather than simulating each component until
the entire Sampler was complete, then trying to debug the entire thing on the FPGA. This
would have involved effectively writing “hardware testbenches” for each module, but the
end result would have probably made debugging much easier. In addition, small but
important details such as the SD card running at a slow clock speed and WAV data being
stored in little-endian format should have been noted early and handled during the initial
design process, not realized during the debug process and fixed at the end.
