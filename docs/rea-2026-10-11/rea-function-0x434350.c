
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00434350(void *this,int param_1)

{
  int *piVar1;
  int iVar2;
  
  piVar1 = (int *)((int)this + 0x178);
  *piVar1 = *piVar1 + param_1;
  if (*piVar1 < 0) {
    if (DAT_004f2a30 != 0) {
      iVar2 = FUN_00435620((int)this);
      *(undefined4 *)(iVar2 + 0x4c) = 0xfa0a1f00;
      return;
    }
    *(undefined4 *)((int)this + 0x178) = 0;
    FUN_00436a10(this,1,0x48);
    _DAT_004fdb24 = this;
    FUN_00431100(0xc1e);
    FUN_00436570(this,9);
    _DAT_004fdb20 = this;
    _DAT_004fdb24 = this;
    FUN_0042ab30(&DAT_005090b0,1,(int *)&DAT_004fdb20);
  }
  if (DAT_0049e96c < *(int *)((int)this + 0x178)) {
    *(int *)((int)this + 0x178) = DAT_0049e96c;
  }
  FUN_0043cb00(DAT_004fe7ac,0x1fa,*(byte **)((int)this + 0x178),*(byte **)((int)this + 0x38));
  return;
}

