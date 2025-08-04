# PTI File Format Comparison: pti.txt vs pti2.txt

## **Major Structural Differences**

### **1. Documentation Approach**
- **pti.txt**: Raw byte-offset approach with detailed offset tables
- **pti2.txt**: Structured C-style approach with data types and structs

### **2. File Size Structure**
- **pti.txt**: Header = 392 bytes, then PCM data
- **pti2.txt**: Header = 16 bytes, Instrument Data = 374 bytes, CRC = 4 bytes (total 394 bytes)

### **3. Header Size Discrepancy**
- **pti.txt**: Claims 392-byte header
- **pti2.txt**: 16-byte file header + 374-byte instrument data structure

## **Critical Field Differences**

### **4. Volume Field Interpretation**
- **pti.txt**: 
  - Offset 272: Volume with **CORRECTED** note stating "50 = 0.0 dB (unity)"
  - Previous documentation was wrong about -/+24 dB range
- **pti2.txt**: 
  - Offset 247: Volume (0-100, logarithmic scale, converted to dB for display)

### **5. File Header Structure**
- **pti.txt**: 
  - Offsets 0-1: "TI" ASCII characters
  - Complex series of critical bytes (offsets 5, 6, 8-11, 12, 13, 16, etc.)
- **pti2.txt**: 
  - Structured header with firmware version, file structure version, size fields
  - Clean 16-byte header

### **6. Critical Export Requirements**
- **pti.txt**: Extensive section on critical export requirements with specific byte values
- **pti2.txt**: No mention of critical export requirements

### **7. Additional Features in pti2.txt**
- **CRC Checksum**: 4-byte CRC at end of file (not mentioned in pti.txt)
- **Python Script Reference**: Mentions `instrumentRead.py` for inspection
- **Structured Envelope/LFO Definitions**: Clean struct layouts

## **Field Mapping Inconsistencies**

### **8. Sample Length Field**
- **pti.txt**: Offsets 60-63 (4 bytes) - Sample length as long (0-4294967295)
- **pti2.txt**: Offset 40 (4 bytes) - 16bit sample count

### **9. Wavetable Fields**
- **pti.txt**: 
  - Offsets 64-65: Wavetable window size (short: 32, 64, 128, 256, 1024, 2048)
  - Offsets 68-69: Wavetable total positions (recommend 94)
- **pti2.txt**: 
  - Offset 44: wavetable_window_size (32, 64, 128, 256, 512, 1024, 2048)
  - Offset 48: wavetableWindowCount

### **10. Playback Modes**
- **Both documents agree on playback mode values 0-7**
- **pti.txt** emphasizes Beat Slice (mode 5) as "CONFIRMED WORKING" for RX2/drum loops

## **Version and Context Differences**

### **11. Firmware Reference**
- **pti.txt**: Based on firmware version 1.5.0b2 analysis
- **pti2.txt**: More generic, includes firmware version as part of file structure

### **12. Critical Warnings**
- **pti.txt**: Heavy emphasis on critical fields that MUST be set correctly for export
- **pti2.txt**: More descriptive but less warning-heavy

## **Conclusion**

**pti.txt** appears to be a reverse-engineered specification focused on practical export requirements, while **pti2.txt** appears to be a more formal, structured specification possibly from official documentation or deeper analysis.

The **major discrepancy** is in the header size interpretation - pti.txt treats the entire instrument parameter block as "header" (392 bytes), while pti2.txt separates it into a small file header (16 bytes) + instrument data (374 bytes) + CRC (4 bytes).

**Key Takeaway**: If implementing a PTI writer, pti.txt's critical export requirements section is invaluable, while pti2.txt's structured approach is better for clean code implementation.