#include <cstdint>
#include <string>
#include <vector>
#include <iomanip>
#include <unordered_map>
#include <ios>
#include <sstream>
#include <bitset>
#include <fstream>
#include <iostream>
#include <type_traits>

enum class InstructionType { R, I, S, B, U, J };

struct Instruction {
  std::string name;     // Name for reference
  InstructionType type; // instruction type, R, I, S, B, U, J
  uint8_t opcode;   //  The op code value XXX XXXX
  uint8_t funct3;
  uint8_t funct7;
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

inline const Instruction* getInstructions(const std::string& name){
  	static std::unordered_map<std::string, const Instruction*> lookupMap;
  	if(lookupMap.empty()){
		for(const auto& inst: instructions){
	  		lookupMap[inst.name] = &inst;
		}
  	}
  	auto iter = lookupMap.find(name);
  	if(iter != lookupMap.end()){
		return iter->second;
  	}
	return nullptr;
}

struct Register {
    std::string hex_name;     // x0-x31
    std::string name;  // zero, ra, sp, etc.
    int address;          // 0-31
};

const std::vector<Register> registers = {
    {"x0", "zero", 0}, {"x1", "ra", 1}, {"x2", "sp", 2}, {"x3", "gp", 3},
    {"x4", "tp", 4}, {"x5", "t0", 5}, {"x6", "t1", 6}, {"x7", "t2", 7},
    {"x8", "s0", 8}, {"x9", "s1", 9}, {"x10", "a0", 10}, {"x11", "a1", 11},
    {"x12", "a2", 12}, {"x13", "a3", 13}, {"x14", "a4", 14}, {"x15", "a5", 15},
    {"x16", "a6", 16}, {"x17", "a7", 17}, {"x18", "s2", 18}, {"x19", "s3", 19},
    {"x20", "s4", 20}, {"x21", "s5", 21}, {"x22", "s6", 22}, {"x23", "s7", 23},
    {"x24", "s8", 24}, {"x25", "s9", 25}, {"x26", "s10", 26}, {"x27", "s11", 27},
    {"x28", "t3", 28}, {"x29", "t4", 29}, {"x30", "t5", 30}, {"x31", "t6", 31}
};

inline const Register* getRegister(const std::string& name){
	static std::unordered_map<std::string, const Register*> lookupMap;
	if(lookupMap.empty()){
		for(const auto& regist: registers){
			lookupMap[regist.name] = &regist;
			lookupMap["x"+std::to_string(regist.address)]=&regist;
		}	
	}
	auto iter = lookupMap.find(name);
	if(iter != lookupMap.end()){
		return iter->second;
	}
	return nullptr;
}

std::string processRType(std::string line, const Instruction* instruction);

uint32_t currentAddress = 0x0;

void firstPass(std::string filename);

std::string convert_IType_Arithmetic_Imm_Shamt(std::string instructionInput, const Instruction * instruction);
std::string convert_IType_Load_Jump(std::string instructionInput, const Instruction* instruction);

std::string processSType(std::string line, const Instruction* instruction);
std::string processBType(std::string line, const Instruction* instruction);
std::string processUType(std::string line, const Instruction* instruction);
std::string processJType(std::string line, const Instruction* instruction);
uint32_t parseImmediate(const std::string immediate);
int getRegisterAddressSafe(const std::string& registerName);
static std::unordered_map<std::string, int32_t> SymbolTable;
int PC;
void writeLittleEndian(std::ofstream& file, uint32_t val);

int main(int argc, char* argv[]) {
    if (argc != 3) return 1;

    std::string fullInputPath = argv[1];
    std::string basePath = argv[2];

    // ensure basePath ends with '/'
    if (!basePath.empty() && basePath.back() != '/') {
        basePath += '/';
    }

    // extract filename from full path
    // std::string file_name = fullInputPath;
    // size_t lastSlash = file_name.rfind('/');
    // if (lastSlash != std::string::npos) {
    //     file_name = file_name.substr(lastSlash + 1);
    // }

    // // remove .s extension (last 2 characters)
    // file_name = file_name.erase(file_name.length() - 2, 2);

    // create output file paths
    // std::string outputBinPath = basePath + file_name + ".bin";
    // std::string outputHexPath = basePath + file_name + ".hex.txt";
    std::string instrPath = basePath + "instr.txt";
    std::string dataPath = basePath +  "data.txt";

    firstPass(fullInputPath);

    std::ifstream inputFile(fullInputPath);
    if (!inputFile.is_open()) {
        return 1;
    }

    std::ofstream instrFile(instrPath);
    std::ofstream dataFile(dataPath);

    std::string line;  
    int lineNum = 0;
    PC = 0; 
    bool inData = false;
    bool inText = false;
    
    // go through file
    while (std::getline(inputFile, line)) {
        lineNum++;

        // dealing with comments
        size_t commentPos = line.find('#');
        std::string cleanLine = line;
        if (commentPos != std::string::npos) {
            cleanLine = line.substr(0, commentPos);
        }

        std::stringstream ss(cleanLine);
        std::string token; 
        ss >> token;

        // for the labeling, setting the data and text
        if (token == ".data") {
            inData = true;
            inText = false;
            continue;
        }
        if (token == ".text") {
            inData = false;
            inText = true;
            continue;
        }
        if (token == ".word") {
            // Handle multiple comma-separated values: .word 1, 2, 3
            std::string word;
            while (ss >> word) {
                // Strip trailing comma if present
                if (!word.empty() && word.back() == ',') word.pop_back();
                if (word.empty()) continue;
                uint32_t val = parseImmediate(word);
                writeLittleEndian(dataFile, val);
                // NOTE: do NOT increment PC here - PC tracks instruction addresses only
            }
            continue;
        }
        
        if (token.empty() || token == ".globl") {
            continue;
        }

        if (token.find(':') != std::string::npos) {
            if (ss >> token) {
            } else {
                continue;
            }
            // Re-check directives after stripping label
            if (token == ".word") {
                std::string word;
                while (ss >> word) {
                    if (!word.empty() && word.back() == ',') word.pop_back();
                    if (word.empty()) continue;
                    uint32_t val = parseImmediate(word);
                    writeLittleEndian(dataFile, val);
                }
                continue;
            }
        }

        const Instruction *instruction = getInstructions(token);

        std::string label = "";

        // read the instructions and check the types
        if (instruction != nullptr) {
            switch (instruction->type) {

                // r
            case InstructionType::R:
                label = processRType(cleanLine, instruction);
                break;
                // i
                // checks to see which i type to do
            case InstructionType::I:
                if (instruction->name == "ebreak") {
                    // ebreak = 000000000001_00000_000_00000_1110011
                    label = std::string("00000000000100000000000001110011");
                } else if (instruction->name == "ecall") {
                    // ecall  = 000000000000_00000_000_00000_1110011
                    label = std::string("00000000000000000000000001110011");
                } else if (instruction->name == "addi" || instruction->name == "slti" || instruction->name == "sltiu" || instruction->name == "xori" || instruction->name == "ori"|| instruction->name == "andi" || instruction->name == "slli" || instruction->name == "srli" || instruction->name == "srai") {
                    label = convert_IType_Arithmetic_Imm_Shamt(cleanLine, instruction);
                } else if(instruction->name == "lb" || instruction->name == "lh" || instruction->name == "lw" || instruction->name == "lbu" || instruction->name == "lhu" || instruction->name == "jalr") {
                    label = convert_IType_Load_Jump(cleanLine, instruction);
                }
                break;

                // s
            case InstructionType::S:
                label = processSType(cleanLine, instruction);
                break;

                // b
            case InstructionType::B:
                label = processBType(cleanLine, instruction);
                break;

                // u
            case InstructionType::U:
                label = processUType(cleanLine, instruction);
                break;

                // j
            case InstructionType::J:
                label = processJType(cleanLine, instruction);
                break;

            default:
                break;
            }
            
            PC += 4;
        }

        // for the files, make sure it's all good, no errors
        if(!label.empty() && label.length() == 32) {
            uint32_t binaryDecimalForm = std::bitset<32>(label).to_ulong();
            writeLittleEndian(instrFile, binaryDecimalForm);

            // if(binaryFile.is_open()) {

            //     binaryFile << label << std::endl;

            // }


            // // output to binary and hex files
            // uint32_t binaryDecimalForm = std::bitset<32>(label).to_ulong();
            // std::string hexForm = binaryToHex(binaryDecimalForm);

            // if(hexFile.is_open()) {

            //     hexFile << "0x" + hexForm << std::endl;

            // }

        }

  }

  // Note: ebreak in the assembly file encodes correctly via the switch case above.
  // Do NOT append an extra ebreak here.
  
  // close
  dataFile.close();
  instrFile.close();
  inputFile.close();

  return 0;
}

void writeLittleEndian(std::ofstream& file, uint32_t val) {
    for(int i=0; i<4; i++) {
        uint8_t byte = ((val >> (i*8)) & 0xFF);
        file << "0x" << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << (int)byte << "\n";

    }

}

// helpful map, was used for i type func orig when merging
std::string registerToBinary(const std::string registerName) {
  std::unordered_map<std::string, int> registerMap = {
      {"zero", 0}, {"ra", 1},  {"sp", 2},  {"gp", 3},  {"tp", 4},  {"t0", 5},
      {"t1", 6},   {"t2", 7},  {"s0", 8},
      {"s1", 9},   {"a0", 10}, {"a1", 11}, {"a2", 12}, {"a3", 13}, {"a4", 14},
      {"a5", 15},  {"a6", 16}, {"a7", 17}, {"s2", 18}, {"s3", 19}, {"s4", 20},
      {"s5", 21},  {"s6", 22}, {"s7", 23}, {"s8", 24}, {"s9", 25}, {"s10", 26},
      {"s11", 27}, {"t3", 28}, {"t4", 29}, {"t5", 30}, {"t6", 31},

  };

  // basically finds in map and converts to binary
  int binary = registerMap[registerName];
  return std::bitset<5>(binary).to_string();
}

 // r = funct 7 + rs2 + rs1 + funct3 + rd + opcode
std::string processRType(std::string line, const Instruction *instruction) {
  std::stringstream ss(line);
  std::string token;
  std::string rd;
  std::string rs1;
  std::string rs2;
  std::string funct7;
  std::string funct3;
  std::string opcode;

  // parse lin
  ss >> token; 
  if (token.find(':') != std::string::npos) {
      ss >> token;
  }
  
  ss >> rd;
  if (!rd.empty() && rd.back() == ',') 
    rd.pop_back();

  ss >> rs1;
  if (!rs1.empty() && rs1.back() == ',')
    rs1.pop_back();

  ss >> rs2;
  if (!rs2.empty() && rs2.back() == ',')
    rs2.pop_back();

  std::string binary_rd = registerToBinary(rd);
  std::string binary_rs1 = registerToBinary(rs1);
  std::string binary_rs2 = registerToBinary(rs2);

  // turn the functs into binary using bitset
  std::string binary_funct7 = std::bitset<7>(instruction->funct7).to_string();
  std::string binary_funct3 = std::bitset<3>(instruction->funct3).to_string();
  std::string binary_opcode = std::bitset<7>(instruction->opcode).to_string();

  // // result = funct7 + rs2 + rs1 + funct3 + rd + opcode;
  // std::cout << std::endl;
  // std::cout << "Printing important details for this line\n\t";
  // std::cout << rd + "\n\t" + rs1 + "\n\t" + rs2 << std::endl;

  // get final result
  std::string binaryResult = binary_funct7 + binary_rs2 + binary_rs1 +
                           binary_funct3 + binary_rd + binary_opcode;

    return binaryResult;

}

// for i type
std::string convert_IType_Arithmetic_Imm_Shamt(std::string instructionInput, const Instruction * instruction) {
	// my thought was to get stream 
    std::istringstream sstream(instructionInput);
	std::string instructionToken;
	std::vector<std::string> instructionTokens;

	while(sstream >> instructionToken) {
		instructionTokens.push_back(instructionToken);
	}
	
    // error checks 
	int offset = 0;
	if (!instructionTokens.empty() && instructionTokens[0].find(':') != std::string::npos) {
		offset = 1;
	}
	
    if(instructionTokens.size() < offset + 4) {
        return std::string(32, '0'); 
    }

    // for the rd, get rid of comma
	std::string rd = instructionTokens[offset + 1];
	int commaIndex = rd.find(",");
	if(commaIndex != std::string::npos) {
        rd.erase(commaIndex, 1);
    }

    // for the rs, get rid of comma

	std::string rs1 = instructionTokens[offset + 2];
	commaIndex = rs1.find(",");
	if(commaIndex != std::string::npos) {
        rs1.erase(commaIndex, 1);
    }

    // imm 
	std::string immshamt = instructionTokens[offset + 3];

    // error checks for reg rd and rs1
    const Register* rd_reg = getRegister(rd);
    const Register* rs1_reg = getRegister(rs1);
    
    if (rd_reg == nullptr || rs1_reg == nullptr) {
        return std::string(32, '0');
    }

    // convert to bits
	rd = std::bitset<5>(getRegister(rd)->address).to_string();
	rs1 = std::bitset<5>(getRegister(rs1)->address).to_string();

    int immediateValue = parseImmediate(immshamt);

    // For shift instructions (slli, srli, srai), the 12-bit imm field is
    // funct7[6:0] | shamt[4:0]. srai has funct7=0x20, srli/slli have funct7=0x00.
    uint32_t imm12val;
    if (instruction->name == "srai" || instruction->name == "srli" || instruction->name == "slli") {
        imm12val = (((uint32_t)instruction->funct7 << 5) | ((uint32_t)immediateValue & 0x1F)) & 0xFFF;
    } else {
        imm12val = (uint32_t)immediateValue & 0xFFF;
    }
    immshamt = std::bitset<12>(imm12val).to_string();

    // return
	return (immshamt+rs1+std::bitset<3>((instruction->funct3) & 0xFFF).to_string()+rd+std::bitset<7>((instruction->opcode) & 0xFFF).to_string());
}

// i type but for load
std::string convert_IType_Load_Jump(std::string instructionInput, const Instruction* instruction) {
    // get stream
	std::istringstream sstream(instructionInput);
	std::string instructionToken;
	std::vector<std::string> instructionTokens;

	while(sstream >> instructionToken) {
		instructionTokens.push_back(instructionToken);
	}

    // if error
    if(instructionTokens.size() < 3) {
        return std::string(32, '0');
    }

    // get rid of commas
	std::string rd = instructionTokens[1];
	int commaIndex = rd.find(",");
	if(commaIndex != std::string::npos) {  
        rd.erase(commaIndex, 1);
    }


	std::string offsetrs1 = instructionTokens[2];
    std::string offsetStr, rs1;

    if (offsetrs1.find('(') != std::string::npos) {
        // Format: lw/jalr rd, offset(rs1)
        offsetStr = offsetrs1.substr(0, offsetrs1.find('('));
        int leftparenthesis  = offsetrs1.find('(');
        int rightparenthesis = offsetrs1.find(')');
        rs1 = offsetrs1.substr(leftparenthesis+1, rightparenthesis-leftparenthesis-1);
    } else {
        // Format: jalr rd, rs1, imm  (three separate operands)
        if (!offsetrs1.empty() && offsetrs1.back() == ',') offsetrs1.pop_back();
        rs1 = offsetrs1;
        offsetStr = (instructionTokens.size() >= 4) ? instructionTokens[3] : "0";
    }

    int offset = parseImmediate(offsetStr);
    std::string imm = std::bitset<12>(offset & 0xFFF).to_string();

    const Register* rd_reg  = getRegister(rd);
    const Register* rs1_reg = getRegister(rs1);

    // null check again
    if (rd_reg == nullptr || rs1_reg == nullptr) {
        return std::string(32, '0');
    }

    // convert to bits
	rd  = std::bitset<5>(rd_reg->address).to_string();
	rs1 = std::bitset<5>(rs1_reg->address).to_string();

	return (imm+rs1+std::bitset<3>(instruction->funct3).to_string()+rd+std::bitset<7>(instruction->opcode).to_string());
}

// for b types
std::string processBType(std::string line, const Instruction *instruction) {
  // b = imm12 + imm10_5 + rs2 + rs1 + funct3 + imm4_1 + imm11 + opcode
  std::stringstream ss(line);
  std::string token;
  std::string rs1;
  std::string rs2;
  std::string label;


  // parse line: beq rs1, rs2, label
  ss >> token; 
  ss >> rs1;
  if (!rs1.empty() && rs1.back() == ',')
    rs1.pop_back();

  ss >> rs2;
  if (!rs2.empty() && rs2.back() == ',')
    rs2.pop_back();

  ss >> label;

  // collect rs1 and rs2 register values
  const Register* reg1 = getRegister(rs1);
  uint32_t rs1_b = 0;
  if (reg1 != nullptr) {
    rs1_b = reg1->address;
  } 
  const Register* reg2 = getRegister(rs2);
  uint32_t rs2_b = 0;
  if (reg2 != nullptr) {
    rs2_b = reg2->address;
  } 
// get funct3 from instruction struct
  uint32_t funct3_b = instruction->funct3;

  auto it = SymbolTable.find(label);
  uint32_t label_b = 0;
  if (it != SymbolTable.end()) {
    label_b = it->second;
  } 
// compute offset (label address - PC), then >> 1
  int32_t offset = label_b - PC;

  uint32_t imm12   = (offset >> 12) & 0x1;
  uint32_t imm11   = (offset >> 11) & 0x1;
  uint32_t imm10_5 = (offset >> 5)  & 0x3F;
  uint32_t imm4_1  = (offset >> 1)  & 0xF;

  uint32_t inst = 0;
  inst |= (imm12   << 31);
  inst |= (imm10_5 << 25);
  inst |= (rs2_b   << 20);
  inst |= (rs1_b   << 15);
  inst |= (funct3_b << 12);
  inst |= (imm4_1  << 8);
  inst |= (imm11   << 7);
  inst |= instruction->opcode; 

  return std::bitset<32>(inst).to_string();

}

std::string processSType(std::string line, const Instruction* instruction)
{
	std::stringstream ss(line);
	std::string token;
	std::string rs1;
	std::string rs2;
	std::string offset;
	std::string funct3;
	std::string opcode;

    // parse lin
	ss >> token; 
	ss >> rs2; 
	rs2.pop_back();
	ss >> offset; 		
	// gets offset and next rs1
	//funct3 = instruction->funct3;
	//opcode = instruction->opcode;

    // deal with the parentheses
	int start = offset.find('(');
	int end = offset.find(')');

	rs1 = offset.substr(start+1, end - start -1);
	offset = offset.substr(0, start);

	int rs2_int = getRegisterAddressSafe(rs2);
    int rs1_int = getRegisterAddressSafe(rs1);

    // get the imm and do magic to get substr
    uint32_t imm_val = parseImmediate(offset);
    std::string imm_str = std::bitset<12>(imm_val).to_string();
	std::string imm_40 = imm_str.substr(7);
	std::string imm_115 = imm_str.substr(0,7);

	std::string binary = imm_115 + std::bitset<5>(rs2_int).to_string()+std::bitset<5>(rs1_int).to_string()+ std::bitset<3>(instruction->funct3).to_string()+imm_40 + std::bitset<7>(instruction->opcode).to_string();

  return binary;

}

std::string processUType(std::string line, const Instruction* instruction)
{
	std::stringstream ss(line);
	std::string token;
	std::string rd;
	std::string imm;
	std::string opcode;
	int rd_int;

    // get rid of commas
	ss >> token; 	
	ss >> rd;
	if (!rd.empty() && rd.back() == ',')
		rd.pop_back();
	ss >> imm; 	
	
	const Register* reg = getRegister(rd);
	if (reg == nullptr) {
		return std::string(32, '0');
	}
	rd_int = reg->address;

    // helper func for dealing with the arr stuff
	uint32_t imm_value = parseImmediate(imm);

    // convert to binary
	std::string binary;
	binary = std::bitset<20>(imm_value).to_string() + std::bitset<5>(rd_int).to_string() + std::bitset<7>(instruction->opcode).to_string();
	return binary;
}

// j types
std::string processJType(std::string line, const Instruction* instruction)
{

	std::stringstream ss(line);
	std::string token;
	std::string rd;
	std::string label;
	std::string opcode;
	int rd_int;

	ss >> token; 	
	if (token.find(':') != std::string::npos) {
		ss >> token; 
	}
	
	ss >> rd;
	if (!rd.empty() && rd.back() == ',')
		rd.pop_back();
	ss >> label; 
	
	if (rd.empty() || label.empty()) {
		return std::string(32, '0');
	}
	
	const Register* reg = getRegister(rd);
	if (reg == nullptr) {
		return std::string(32, '0');
	}
	rd_int = reg->address;

	int32_t offset = 0;
    // look for label in symbol table
	if (SymbolTable.find(label) != SymbolTable.end()) {
		int32_t target_addr = SymbolTable[label];
		offset = target_addr - PC;
	} else {
		return std::string(32, '0');
	}

    // do magic for the imm values in the format
	uint32_t imm20 = (offset >> 20) & 0x1;    
	uint32_t imm19_12 = (offset >> 12) & 0xFF;
	uint32_t imm11 = (offset >> 11) & 0x1;
	uint32_t imm10_1 = (offset >> 1) & 0x3FF;
	
	uint32_t inst = 0;
	inst |= (imm20 << 31);
	inst |= (imm10_1 << 21);
	inst |= (imm11 << 20);
	inst |= (imm19_12 << 12);
	inst |= (rd_int << 7);
	inst |= instruction->opcode;

	std::string binary = std::bitset<32>(inst).to_string();
	return binary;
}


// helper funct for the hi and lo stuff
uint32_t parseImmediate(const std::string immediate) {
    if (immediate.empty()) return 0;

    if(immediate.find("%hi")==0) {
        int startIndex = immediate.find('(')+1;
        int endIndex = immediate.find(')');
        if (startIndex == 0 || endIndex == std::string::npos) return 0;
        std::string imm = immediate.substr(startIndex, endIndex-startIndex);
        if(SymbolTable.find(imm)!=SymbolTable.end()) {
            int address = SymbolTable[imm];
            return(address>>12)&0xFFFFF;
        } else {
            return 0;
        }
    }

    if(immediate.find("%lo")==0) {
        int startIndex = immediate.find('(')+1;
        int endIndex = immediate.find(')');
        if (startIndex == 0 || endIndex == std::string::npos) return 0;
        std::string imm = immediate.substr(startIndex, endIndex-startIndex);
        if(SymbolTable.find(imm)!=SymbolTable.end()) {
            int address = SymbolTable[imm];
            return address & 0xFFF;
        } else {
            return 0;
        }
    }

    if (immediate.find("0x") == 0 || immediate.find("0X") == 0) {
        try {
            return std::stoul(immediate, nullptr, 16);
        } catch (...) {
            return 0;
        }
    }

    if (SymbolTable.find(immediate) != SymbolTable.end()) {
        return SymbolTable[immediate];
    }

    try {
        return std::stoi(immediate);
    } catch (...) {
        return 0;
    }
}

// for the first pass of the file for the basic beginning labels
void firstPass(std::string filename) {
	std::ifstream inputFile(filename);
	if (!inputFile.is_open()) {
		return;
	}

	std::string line;
	currentAddress = 0x0;
	bool inDataSection = false;
	uint32_t dataAddress = 0x0;

	while (std::getline(inputFile, line)) {
		size_t commentPos = line.find('#');
		if (commentPos != std::string::npos) {
			line = line.substr(0, commentPos);
		}

		std::stringstream ss(line);
		std::string token;
		if (!(ss >> token)) continue; 

		if (token.back() == ':') {
			std::string labelName = token.substr(0, token.length() - 1);
			if (inDataSection) {
			    SymbolTable[labelName] = dataAddress;
			} else {
			    SymbolTable[labelName] = currentAddress;
			}
			if (!(ss >> token)) continue; 
		}

		if (token == ".data") {
			inDataSection = true;
			continue;
		}
		if (token == ".text") {
			inDataSection = false;
            currentAddress = 0x0;
			continue;
		}
		if (token == ".word") {
			// Count all comma-separated values on this line
			std::string val;
			while (ss >> val) {
				if (!val.empty() && val.back() == ',') val.pop_back();
				if (val.empty()) continue;
				if (inDataSection) dataAddress += 4;
				else currentAddress += 4;
			}
			// Fallback: if no values were parsed (empty line after .word), count one
			// (This shouldn't happen in well-formed assembly)

			continue;
		}
		if (token == ".globl") {
			continue;
		}
		
		if (!inDataSection && getInstructions(token) != nullptr) {
			currentAddress += 4;
		}
	}
	inputFile.close();
}

// safe get register version
int getRegisterAddressSafe(const std::string& registerName) {
    const Register* reg = getRegister(registerName);
    if (reg == nullptr) {
        return 0;
    }
    return reg->address;
}