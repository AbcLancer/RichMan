
byte * __thiscall FUN_00435e50(void *this,int param_1)

{
  uint uVar1;
  byte *pbVar2;
  int iVar3;
  
  uVar1 = FUN_00433530();
  pbVar2 = (byte *)FUN_00433060(&DAT_004e3b18,uVar1,this);
  if (1 < param_1) {
    iVar3 = FUN_00433040(&DAT_004e3b18,(int)pbVar2);
    *(int *)(iVar3 + 0x30) = param_1;
  }
  iVar3 = FUN_00435db0(this,(int)pbVar2,3);
  if (iVar3 == -1) {
    FUN_004330b0(&DAT_004e3b18,(int)pbVar2);
    return (byte *)0xffffffff;
  }
  FUN_0043cb00(DAT_004fe7ac,0x22,pbVar2,(byte *)(param_1 << 4 | uVar1));
  FUN_0043cb00(DAT_004fe7ac,0x1e,(byte *)(iVar3 << 8 | (uint)pbVar2),*(byte **)((int)this + 0x38));
  return pbVar2;
}

