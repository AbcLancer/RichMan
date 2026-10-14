
void __fastcall FUN_0042be40(byte *param_1)

{
  if (*(int *)(param_1 + 0x34) != -1) {
    FUN_0043cb00(DAT_004fe7ac,0x12d,(byte *)0x0,param_1);
    FUN_00431a90(&DAT_004f2e68,*(int *)(param_1 + 0x34));
    param_1[0x34] = 0xff;
    param_1[0x35] = 0xff;
    param_1[0x36] = 0xff;
    param_1[0x37] = 0xff;
  }
  return;
}

