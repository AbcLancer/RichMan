
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_0042ea60(void *this,float param_1,int param_2,int param_3)

{
  float local_40;
  undefined4 local_3c;
  int local_38;
  
  FUN_0042e870(this,param_1,param_2,param_3);
  _DAT_004e3b78 = 1;
  local_40 = param_1;
  if (param_2 == 0) {
    local_3c = 0xff;
  }
  else {
    local_3c = *(undefined4 *)(param_2 + 0x44);
  }
  local_38 = 0xff;
  if (param_3 != -1) {
    local_38 = param_3;
  }
  FUN_0043cb00(DAT_004fe7ac,0xd0,(byte *)0x1,(byte *)&local_40);
  return;
}

