#include "stdio.h"

extern void print(char *out_buf, const char *format, const char *hex_number);

int main()
{
  char *out_buf = malloc(sizeof(char) * 256);
  char *format = malloc(sizeof(char) * 256);
  char *hex_number = malloc(sizeof(char) * 34);
                                 
  snprintf(format, 256, "%s", "0+-10");   //"<-+ 012><wight>"
  snprintf(hex_number, 256, "%s", "00000000000000000000000000000021"); //<->

  print(out_buf, format, hex_number);

  printf("out_buf:%s.\nhex_number:%s\n", out_buf, hex_number);

  free(format);
  free(out_buf);
  free(hex_number);
  return 0;
}

