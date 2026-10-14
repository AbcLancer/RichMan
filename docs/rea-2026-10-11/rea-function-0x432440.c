
void __fastcall FUN_00432440(int param_1)

{
  if (*(int *)(param_1 + 4) != 0) {
    *(undefined4 *)(param_1 + 0x38) = *(undefined4 *)(param_1 + 0x34);
    *(byte *)(param_1 + 0x40) = *(byte *)(param_1 + 0x40) | 1;
  }
  return;
}

