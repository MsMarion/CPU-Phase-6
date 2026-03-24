#ifndef RV32I_H
#define RV32I_H

#include <cstdint>
#include <string>
#include <vector>
#include <iomanip>
#include <unordered_map>
#include <ios>
#include <sstream>


/*
things to do:
- return two files of hex values, instr.txt and data.txt
- both files should store a byte per line and use little endian (0x00AD7318 -> 0x18, 0x73, 0xAD, 0x00)

output:
- instr.txt has encoded instruction commands (with the little endians)
- data.txt has word data initially stored in data
- end each file with an ebreak signal, urrently in each assembly file that is input for assembler
- should decode to 0x00100073
*/

enum class InstructionType { R, I, S, B, U, J };

struct Instruction {
  std::string name;     // Name for reference
  InstructionType type; // instruction type, R, I, S, B, U, J
  uint8_t opcode;   //  The op code value XXX XXXX
  uint8_t funct3;
  uint8_t funct7;
  //int numOperands;  //  Used to know how many operands are needed to look for
};

const std::vector<Instruction> instructions = {
	// R-Type
	{"add", InstructionType::R, 0x33, 0x0, 0x00},
	{"sub", InstructionType::R, 0x33, 0x0, 0x20},
	{"sll", InstructionType::R, 0x33, 0x1, 0x00},
	{"slt", InstructionType::R, 0x33, 0x2, 0x00},
	{"sltu", InstructionType::R, 0x33, 0x3, 0x00},
	{"xor", InstructionType::R, 0x33, 0x4, 0x00},
	{"srl", InstructionType::R, 0x33, 0x5, 0x00},
	{"sra", InstructionType::R, 0x33, 0x5, 0x20},
	{"or", InstructionType::R, 0x33, 0x6, 0x00},
	{"and", InstructionType::R, 0x33, 0x7, 0x00},

	// I-Type
	{"jalr", InstructionType::I, 0x67, 0x0, 0x00},
	{"lb", InstructionType::I, 0x03, 0x0, 0x00},
	{"lh", InstructionType::I, 0x03, 0x1, 0x00},
	{"lw", InstructionType::I, 0x03, 0x2, 0x00},
	{"lbu", InstructionType::I, 0x03, 0x4, 0x00},
	{"lhu", InstructionType::I, 0x03, 0x5, 0x00},
	{"addi", InstructionType::I, 0x13, 0x0, 0x00},
	{"slti", InstructionType::I, 0x13, 0x2, 0x00},
	{"sltiu", InstructionType::I, 0x13, 0x3, 0x00},
	{"xori", InstructionType::I, 0x13, 0x4, 0x00},
	{"ori", InstructionType::I, 0x13, 0x6, 0x00},
	{"andi", InstructionType::I, 0x13, 0x7, 0x00},
	{"slli", InstructionType::I, 0x13, 0x1, 0x00},
	{"srli", InstructionType::I, 0x13, 0x5, 0x00},
	{"srai", InstructionType::I, 0x13, 0x5, 0x20},

	// S-Type
	{"sb", InstructionType::S, 0x23, 0x0, 0x00},
	{"sh", InstructionType::S, 0x23, 0x1, 0x00},
	{"sw", InstructionType::S, 0x23, 0x2, 0x00},

	// B-Type
	{"beq", InstructionType::B, 0x63, 0x0, 0x00},
	{"bne", InstructionType::B, 0x63, 0x1, 0x00},
	{"blt", InstructionType::B, 0x63, 0x4, 0x00},
	{"bge", InstructionType::B, 0x63, 0x5, 0x00},
	{"bltu", InstructionType::B, 0x63, 0x6, 0x00},
	{"bgeu", InstructionType::B, 0x63, 0x7, 0x00},

	// U-Type
	{"lui", InstructionType::U, 0x37, 0x0, 0x00},
	{"auipc", InstructionType::U, 0x17, 0x0, 0x00},

	// J-Type
	{"jal", InstructionType::J, 0x6F, 0x0, 0x00},

	// System
	{"ecall", InstructionType::I, 0x73, 0x0, 0x00},
	{"ebreak", InstructionType::I, 0x73, 0x0, 0x01}
};

// method to create hashmap of instructions and do lookup for time saving
inline const Instruction* getInstructions(const std::string& name){

  	static std::unordered_map<std::string, const Instruction*> lookupMap;

  	if(lookupMap.empty()){
		for(const auto& inst: instructions){
	  		lookupMap[inst.name] = &inst;
		}
  	}

  	std::unordered_map<std::string, const Instruction*>::iterator iter = lookupMap.find(name);

  	if(iter != lookupMap.end()){
		return iter->second;
  	}

	return nullptr; // cant find it

}

inline std::string typeToString(InstructionType type) {
    switch (type) {
        case InstructionType::R: return "R";
        case InstructionType::I: return "I";
        case InstructionType::S: return "S";
        case InstructionType::B: return "B";
        case InstructionType::U: return "U";
        case InstructionType::J: return "J";
        default: return "Unknown";
    }
}

// Convert 32-bit binary result to hex
std::string binaryToHex(uint32_t inst) {
  std::stringstream ss;
  ss << std::uppercase << std::setfill('0') << std::setw(8)
     << std::hex << inst;
  return ss.str();
}


struct Register {
    std::string hex_name;     // x0-x31
    std::string name;  // zero, ra, sp, etc.
    int address;          // 0-31
};

const std::vector<Register> registers = {
    {"x0", "zero", 0},
    {"x1", "ra", 1},
    {"x2", "sp", 2},
    {"x3", "gp", 3},
    {"x4", "tp", 4},
    {"x5", "t0", 5},
    {"x6", "t1", 6},
    {"x7", "t2", 7},
    {"x8", "s0", 8},
    {"x9", "s1", 9},
    {"x10", "a0", 10},
    {"x11", "a1", 11},
    {"x12", "a2", 12},
    {"x13", "a3", 13},
    {"x14", "a4", 14},
    {"x15", "a5", 15},
    {"x16", "a6", 16},
    {"x17", "a7", 17},
    {"x18", "s2", 18},
    {"x19", "s3", 19},
    {"x20", "s4", 20},
    {"x21", "s5", 21},
    {"x22", "s6", 22},
    {"x23", "s7", 23},
    {"x24", "s8", 24},
    {"x25", "s9", 25},
    {"x26", "s10", 26},
    {"x27", "s11", 27},
    {"x28", "t3", 28},
    {"x29", "t4", 29},
    {"x30", "t5", 30},
    {"x31", "t6", 31}
};


inline const Register* getRegister(const std::string& name){

	static std::unordered_map<std::string, const Register*> lookupMap;

	if(lookupMap.empty()){
		for(const auto& regist: registers){
			lookupMap[regist.name] = &regist;
			lookupMap["x"+std::to_string(regist.address)]=&regist;
		}
		
	}

	std::unordered_map<std::string, const Register*>::iterator iter = lookupMap.find(name);

	if(iter != lookupMap.end()){
		return iter->second;
	}
	
	return nullptr;
}

#endif // RV32I_H

