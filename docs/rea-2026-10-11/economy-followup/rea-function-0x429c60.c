
undefined4 __cdecl FUN_00429c60(int *param_1)

{
  undefined4 uVar1;
  
  uVar1 = 0;
  if (*param_1 == 3) {
    return 0x11;
  }
  if (param_1[2] == 3) {
    return 5;
  }
  if (param_1[1] == 3) {
    return 3;
  }
  if (*param_1 == 2) {
    uVar1 = 2;
  }
  return uVar1;
}

