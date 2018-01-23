#include "stdio.h"

//extern void print(char *out_buf, const char *format, const char *hex_number);
extern void test_asm(char *out_buf, const char *hex_number);

int main()
{
  char *out_buf = malloc(sizeof(char) * 256);
  char *hex_number = malloc(sizeof(char) * 33);

  snprintf(hex_number, 256, "%s\0", "fffffffffffffffffffffffffffffff1");
  //snprintf(out_buf, 1024, "%s\0", "12345678901234567890123456789012");

  test_asm(out_buf, hex_number);

  printf("out_buf: %s\nhex_number: %s\n", out_buf, hex_number);

  free(out_buf);
  free(hex_number);
  return 0;
}

