
void __thiscall FUN_00429df0(void *this,byte *param_1,int param_2)

{
  int iVar1;
  void *this_00;
  byte *pbVar2;
  
  if ((char)(param_1 + 0xd18)[(int)this] < '\0') {
    iVar1 = FUN_00435620(param_2);
    if (999 < *(int *)(iVar1 + 0x4c)) {
      iVar1 = 0;
      pbVar2 = (byte *)0x3e8;
      this_00 = (void *)FUN_00435620(param_2);
      FUN_0043ff30(this_00,pbVar2,iVar1);
      FUN_0041a9d0(&DAT_004e3b28,1,1.4013e-42);
      (param_1 + 0xd18)[(int)this] = (byte)*(undefined4 *)(param_2 + 0x38);
      FUN_0043cb00(DAT_004fe7ac,0x33,param_1,*(byte **)(param_2 + 0x38));
    }
  }
  return;
}

