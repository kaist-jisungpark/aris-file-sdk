## Understanding ARIS Data

This document discusses the format of data in ARIS recordings (.aris extension) and how to
access the images recorded (the "sample data").

### ARIS Recordings

Any ARIS recording generated by Sound Metrics' tools consists of one or
more images produced by the sonar; each image is referred to as a *frame*. Each
frame contains sample data indicating signal strength of acoustic energy
returned from downfield.

A frame's sample data is a two-dimensional array of sample values,
each sample being one unsigned byte in the range 0-255; this range maps
to an acoustic signal in the range 0-80 dB.

The extent of the sample array's horizontal dimension is the number of
directional beams employed by the ARIS.
The extent of the vertical dimension is the number of samples
taken along a beam (often "samples per beam" or `BeamCount`).

Each frame in a .aris file is of the same size. Beam count and sample count
do not vary within a file.

### Terms

| Term | Description |
| ----- | ----- |
| `BeamCount`  | Number of beams across the image in the horizontal dimension; this is derived from the ping mode used. Beam count can be 48, 64, 96, or 128 depending on the model of ARIS that produced the data. |
| `SampleCount`| Number of samples in a beam in the vertical dimension; this is `SamplesPerBeam` in the frame header.
| `AcousticDataSize`  | Size of the acoustic data samples, which is `(BeamCount * SampleCount)`. |
| `FI` | Frame Index, which is zero-based.

> #### Frame Index
> When processing frame data we always use a frame index (`FI`) that is zero-based.
> However, when presenting frames to the user we always present `FI` as one-based
> (`FI + 1`).
> It's easier for the user and we recommend that you follow this practice in any UI
> you build.  

### ARIS Recording File Format

#### General Structure

Every ARIS file has one `FileHeader` at position 0.
The `FileHeader` is followed by one or more frames.
Each frame consists of a `FrameHeader` followed by sample
data of size `AcousticDataSize`. For example,

| Bytes | Description | Notes |
| -----: | ----- | ----- |
| 1024 | `FileHeader` | There is one file header per file, it starts at position 0. |
| 1024 | `FrameHeader` | Frame 0 header |
| `AcousticDataSize` | Frame Sample Data | Frame 0 sample data.
| 1024 | `FrameHeader` | Frame 1 header |
| `AcousticDataSize` | Frame Sample Data | Frame 1 sample data.
| ... | | | |

The offset of each frame in the file is
`(1024 + [FI * (1024 + FrameSize)])`,
where `FI` is the zero-based frame index.
(The initial 1024 is the size of `FileHeader`,
the second 1024 is the size of `FrameHeader`). 

Type definitions for `FileHeader` and `FrameHeader` are found in
[type_definitions](https://github.com/SoundMetrics/aris-file-sdk/tree/master/type_definitions).

> #### Implementation Note
> File offsets should be calculated with 64-bit values 
in order to read large files correctly. 32-bit values are not
sufficient to correctly extract data from large files.

#### Notes

The ARIS file format was derived from the earlier DIDSON DDF_04 
file format. 
Many of the parameters in both the Master Header and Frame Header 
are legacy parameters from DIDSON files, and are not used at all 
in ARIS files. 
They were preserved to allow backward compatibility. 

#### Header Fields of Interest

The following subset of parameters are actively used in ARIS files 
and necessary or useful for image generation and post-processing.

* `PingMode`
* `SamplePeriod`
* `SoundSpeed`
* `SamplesPerBeam`
* `SampleStartDelay`
* `LargeLens`
* `ReorderedSamples`

`BeamCount`, or the number of beams, is dervied from `PingMode`.
See `get_beams_from_pingmode()` in
[FrameFuncs.c](https://github.com/SoundMetrics/aris-file-sdk/blob/master/common-code/FrameFuncs.c).

See
[type_definitions](https://github.com/SoundMetrics/aris-file-sdk/tree/master/type_definitions)
for a complete
listing of all header fields.

> Most of `FileHeader` can be safely ignored. In particular, it is recommended that you
> ignore `FileHeader.FrameCount`. The frame count is easily calculated from the file
> size and `FrameHeader` information:
> ```
> frameCount := (fileSize - sizeof(FileHeader)) / (sizeof(FrameHeader) + AcousticDataSize)
> ```

### Acoustic Data Ordering

Currently all acoustic data in ARIS (.aris) recordings
are stored in correct order.
This can be confimed by checking that `FrameHeader.ReorderedSamples`
is non-zero.

> System integrators who communicate directly to an ARIS device
> in real time will find that `FrameHeader.ReorderedSamples`
> is zero and will need to reorder data received from the
> ARIS. Systems integrators must always check whether this flag
> is zero. This is covered in the
> [ARIS Integration SDK](https://github.com/SoundMetrics/aris-integration-sdk).
>
> (The **ARIS Integration SDK** is not yet released.)

### Constructing Images From Samples

A single image frame is built from the array of N beams by M samples.
The frame header information is used to calculate the start and end
ranges, and the incremental down range sample distance.
The cross range distance for any given sample is calculated from the
beam spacing table (for angular limits) and linearly increases with
sample range.

> Please note: in ARIS acoustic sample data beam 0 is the right-most
> beam, and beams are numbered from right-to-left.

The SoundSpeed (meters/second) parameter in the frame headers has been
calculated based on water temperature, depth and salinity
(fresh=0, brackish=15, sea=35).
Range dependent values may then be calculated from the frame header
fields as follows:

```
WindowStart(m)   := SampleStartDelay(us) * 1e-6(s/us) * SoundSpeed(m/s) / 2
WindowLength(m)  := SamplePeriod(us) * SamplesPerBeam * 1e-6(s/us) * SoundSpeed(m/s) / 2
RangeStart       := WindowStart
RangeEnd         := WindowStart + WindowLength
SampleRange[idx] := WindowStart + SamplePeriod * idx * 1e-6 * SoundSpeed  / 2
SampleLength     := SamplePeriod *  1e-6 * SoundSpeed  / 2
```

#### Beam Spacing

A simple model assumes evenly spaced beams, but the acoustic lens
introduces a non-linear beam spacing based on the lens type
(ARIS 1200/1800/3000 or Telephoto) and number of beams.
The table below beam spacing files which are based on a
"composite" lens of each type, generated by averaging several
measured beam patterns for each lens type. The beam width source files
are located in
[beam-width-metrics](https://github.com/SoundMetrics/aris-file-sdk/tree/master/beam-width-metrics).

| Sonar/Lens | Beam Count | Beam Width Source |
| :-----:   | -----: | ----- |
| 1200/1800 | 48  | BeamWidths_ARIS1800_1200_48.h |
| 1800      | 96  | BeamWidths_ARIS1800_96.h |
| 3000      | 64  | BeamWidths_ARIS3000_64.h |
| 3000      | 128 | BeamWidths_ARIS3000_128.h |
| Telephoto | 48  | BeamWidths_ARIS_Telephoto_48.h |
| Telephoto | 96  | BeamWidths_ARIS_Telephoto_96.h |

### Sanity Checks

Files and file systems are sometimes corrupted. A corrupt file may cause fatal errors
while processing acoustic sample data. One might perform rudimentary sanity checks on
the frame header fields in use.

The `FileHeader` and `FrameHeader` both have a signature field that can also be used as a
sanity check. The signature fields are named `Version`.
`FileHeader.Version` and `FrameHeader.Version` are both expected to contain the
signature value `0x05464444` in an uncorrupted file and frame.