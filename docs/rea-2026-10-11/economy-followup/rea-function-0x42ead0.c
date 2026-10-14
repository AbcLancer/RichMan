
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_0042ead0(uint param_1,int param_2)

{
  uint local_40;
  uint local_3c;
  
  FUN_0042e990(param_1,param_2);
  _DAT_004e3b78 = 1;
  if ((int)param_1 < 0) {
    param_1 = -param_1 | 0x80;
  }
  local_3c = (uint)(param_2 - DAT_004e383c) / 0x2c;
  local_40 = param_1;
  FUN_0043cb00(DAT_004fe7ac,0xd0,(byte *)0x2,(byte *)&local_40);
  return;
}

