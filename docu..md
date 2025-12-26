# GTA San Andreas Path File Format Documentation

## Data Types
| Type       | Description                                  | Size    |
|------------|----------------------------------------------|---------|
| INT8       | Signed 8-bit integer                         | 1 byte  |
| UINT8      | Unsigned 8-bit integer                       | 1 byte  |
| INT16      | Signed 16-bit integer                        | 2 bytes |
| UINT16     | Unsigned 16-bit integer                      | 2 bytes |
| INT32      | Signed 32-bit integer                        | 4 bytes |
| UINT32     | Unsigned 32-bit integer                      | 4 bytes |
| FLOAT      | Single precision floating point              | 4 bytes |

## Core Concepts
- **Node**: A point in 3D space that anchors a path
- **Path**: Route between nodes, used by peds and vehicles
- **Link**: Connection reference from one node to another-
- **Navigation Node**: Specialized points between vehicle nodes that provide additional path information:
## File Structure

### Header (20 bytes)
| Offset | Type    | Description              |
|--------|---------|--------------------------|
| 0x00   | UINT32  | Number of nodes         |
| 0x04   | UINT32  | Number of vehicle nodes |
| 0x08   | UINT32  | Number of ped nodes     |
| 0x0C   | UINT32  | Number of navi nodes    |
| 0x10   | UINT32  | Number of links         |

### Path Node (28 bytes)
| Offset | Type     | Description                            |
|--------|----------|----------------------------------------|
| 0x00   | UINT32   | Memory Address (unused)               |
| 0x04   | UINT32   | Unused (always zero)                  |
| 0x08   | INT16[3] | Position XYZ (divide by 8)            |
| 0x0E   | INT16    | Heuristic cost (0x7FFE)              |
| 0x10   | UINT16   | Link ID                               |
| 0x12   | UINT16   | Area ID                               |
| 0x14   | UINT16   | Node ID                               |
| 0x16   | UINT8    | Path Width                            |
| 0x17   | UINT8    | Flood Fill                            |
| 0x18   | UINT32   | Flags                                 |

### Navi Node (14 bytes)
| Offset | Type     | Description                           |
|--------|----------|---------------------------------------|
| 0x00   | INT16[2] | Position XY (divide by 8)            |
| 0x04   | UINT16   | Area ID                              |
| 0x06   | UINT16   | Node ID                              |
| 0x08   | INT8[2]  | Direction XY (-100 to 100)           |
| 0x0A   | UINT32   | Flags                                |

## Flag Definitions

### Path Node Flags
```
Bits  Description
0-3   Link Count
4     onDeadEnd
5     switchedOff
6     Road Blocks
7     Boats
8     Emergency Vehicles Only
9     Unused
10    Grove House Entrance
11    Unused
12    Not Highway
13    Is Highway
14-15 Unused
16-19 Spawn Probability  (0-15)
20-23 Special Flag   "1 - PARKING_PARALLEL", "2 - PARKING_PERPENDICULAR", "3 - VALET", "4 - NIGHTCLUB", "5 - DELIVERIES", "6 - VALET_UNLOAD", "7 - NIGHTCLUB_UNLOAD", "8 - DRIVE_THROUGH", "9 - DRIVE_THROUGH_WINDOW", "10 - DELIVERIES_UNLOAD"
24-31 Unused
```

### Navi Node Flags
```
Bits   Description
0-7    Path Width
8-10   Left Lanes (0-7)
11-13  Right Lanes (0-7)
14     Traffic Light Direction
15     Unused
16-17  Traffic Light Behavior (0=Off, 1=NS, 2=WE)
18     Train Crossing
19-31  Unused
```

## Notes
- World coordinates are stored as integers divided by 8
- Direction vectors are normalized between -100 and 100
- Navi nodes must link from higher to lower area/node IDs
- Maximum 1024 navi nodes per area
- Maximum 64 areas supported
