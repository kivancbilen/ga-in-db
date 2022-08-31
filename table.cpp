#include <string>
#include <vector>
#include <sstream>
#include "search.cu"
#include <iostream>
#include "sort.cu"

using namespace std;

class table {       // The class
public:             // Access specifier
    string name;        // Attribute (int variable)
    vector<string> fields;  // Attribute (string variable)
    vector<char> rows;
    CudaTable* ts;
    int rowsize;
    table(string _name, vector<string> _fields) {
        name = _name;
        fields = _fields;
        rowsize = 24;
        ts = new CudaTable();
    }

    void padTo(std::string& str, const size_t num, const char paddingChar = ' ')
    {
        if (num > str.size()) {
            //str.insert(0, num - str.size(), paddingChar);
            str.insert(0, num - str.size(), paddingChar);
        }
    }

    char* intToArray(int number)
    {
        int n = log10(number) + 1;
        int i;
        char* numberArray = (char*)calloc(n, sizeof(char));
        for (i = n - 1; i >= 0; --i, number /= 10)
        {
            numberArray[i] = (number % 10) + '0';
        }
        return numberArray;
    }

    string gen_random(const int len) {
        static const char alphanum[] =
            "0123456789"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "abcdefghijklmnopqrstuvwxyz";
        string tmp_s;
        tmp_s.reserve(len);

        for (int i = 0; i < len; ++i) {
            tmp_s += alphanum[rand() % (sizeof(alphanum) - 1)];
        }

        return tmp_s;
    }

    void insert50000() {
        

        string segment;
        vector<string> segfldlist = { "id", "name", "surname" };
        


        
        
        
        int size = 1048576;
        for (int32_t i = 0; i < size-2; i++)
        {
            string val = "";
            string istr = to_string(i);
            string name = gen_random(8);
            string surname = gen_random(8);
            padTo(istr, 8, ' ');
            val += istr;
            val += name;
            val += surname;
           
            vector<char> buffer(24);
            for (size_t i = 0; i < 24; i++)
            {
                buffer[i] = val[i];
            }
            rows.insert(rows.end(), buffer.begin(), buffer.end());
        }
        string val2 = "";
        string istr = to_string(0);
        string name = "kivanc";
        string surname = "bilen";
        padTo(istr, 8, ' ');
        padTo(name, 8, ' ');
        padTo(surname, 8, ' ');
        val2 += istr;
        val2 += name;
        val2 += surname;

        vector<char> buffer2(24);
        for (size_t i = 0; i < 24; i++)
        {
            buffer2[i] = val2[i];
        }
        rows.insert(rows.end(), buffer2.begin(), buffer2.end());
        rows.insert(rows.end(), buffer2.begin(), buffer2.end());

        ts->insertToGPU((char*)&rows[0], rows.size());

    }
    void insert(string _fields, string _values) {
        stringstream flds(_fields);
        stringstream vals(_values);

        string segment;
        vector<string> segfldlist;
        vector<string> segvallist;


        while (getline(flds, segment, ','))
        {
            segfldlist.push_back(segment);
        }
        while (getline(vals, segment, ','))
        {
            segvallist.push_back(segment);
        }
        int fieldsSize = fields.size();
        int valsSize = segfldlist.size();
        string val = "";

        for (size_t i = 0; i < fieldsSize; i++)
        {
            bool check = false;
            for (size_t j = 0; j < valsSize; j++)
            {
                if (fields[i] == segfldlist[j]) {
                    check = true;
                    val += segvallist[j];
                    val += "\|";
                }
            }
            if (!check) {
                val += "\|";
            }
        }
        //rows.push_back(val);
    }

    vector<char> read() {
        return rows;
    }

    string search0(string _field, string _value) {
        unsigned int size = 65536;
        float test[65536];
        for (size_t i = 0; i < size; i++)
        {
            test[i] = i;
        }
        int result[1] = { -1 };
        //sortWithCuda(test, size);
        ts->searchWithCuda(test, result, size);
        
        
        return "";
    }

    string search(string _field, string _value) {
        

        vector<int> result;
       
        //char res[1048576] = { -1 };
        string searchvalue = "kivanc";
        padTo(searchvalue, 8, ' ');
        char char_array[9];
        strcpy(char_array, searchvalue.c_str());
        
        std::chrono::steady_clock::time_point begin0 = std::chrono::steady_clock::now();

        ts->searchStringWithCudaGPU(rows.size(), rows.size(), 1, char_array, rowsize, 8);
        char* res = ts->resultarray;
        std::chrono::steady_clock::time_point end0 = std::chrono::steady_clock::now();
        std::cout << "Time difference cuda = " << std::chrono::duration_cast<std::chrono::microseconds>(end0 - begin0).count() << "[microseconds]" << std::endl;

        std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();
        for (size_t i = 0; i < 1024*1024; i++)
        {
            if (ts->resultarray[i] == '\x1') {
                result.push_back(i);
            }
        }
        if (result.size() > 0) {
            vector<char>::const_iterator first = rows.begin() + result[0] * 24;
            vector<char>::const_iterator last = rows.begin() + result[0] * 24 + 24;
            vector<char> newVec(first, last);
            for (int i = 0; i < 24; ++i)
            {
                cout << newVec[i];
            }
            std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();
            std::cout << "Time difference = " << std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count() << "[microseconds]" << std::endl;
            for (int i = 0; i < 24; ++i)
            {
                cout << rows[i];
            }
        }
        return "";
    }

    void update(string _value) {
        std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();
        vector<int> result;


        string searchvalue = _value;
        padTo(searchvalue, 8, ' ');
        char char_array[9];
        strcpy(char_array, searchvalue.c_str());

        ts->searchStringWithCudaGPU(rows.size(), rows.size(), 1, char_array, rowsize, 8);
        for (size_t i = 0; i < 1024 * 1024; i++)
        {
            if (ts->resultarray[i] == '\x1') {
                result.push_back(i);
            }
        }
        vector<char>::const_iterator first = rows.begin() + result[0] * 24;
        vector<char>::const_iterator last = rows.begin() + result[0] * 24 + 24;
        vector<char> newVec(first, last);


        string updateValue = "kivanc";
        padTo(updateValue, 8, ' ');
        char char_array_update[9];
        strcpy(char_array_update, updateValue.c_str());
        for (int i = 0; i < 8; i++) {
            newVec[8 + i] = char_array_update[i];
        }
        memcpy(&rows[0], &newVec[0], 24);
        ts->updateGPU((char*)&newVec[0], rowsize, result[0] * 24);
    }

    string sort() {
        unsigned int size = 131072;

        float test[131072];
        for (size_t i = 0; i < size; i++)
        {
            test[i] = rand() % size;
        }



        sortWithCuda(test, size);

        return "";
    }
};