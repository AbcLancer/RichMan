
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00432d60(void *this,int param_1)

{
  uint uVar1;
  
  if (param_1 == 8) {
    _DAT_004fdb20 = *(undefined4 *)this;
    FUN_0042ab30(&DAT_005090b0,*(int *)((int)this + 4) + 0x8a,(int *)&DAT_004fdb20);
    return;
  }
  if (param_1 == 1) {
    uVar1 = 1;
  }
  else if (param_1 == 2) {
    uVar1 = FUN_00405130(2,4);
  }
  else {
    uVar1 = param_1 + 2;
  }
  FUN_0043cb00(DAT_004fe7ac,0x3f8,(byte *)(*(int *)((int)this + 4) << 4 | uVar1),
               *(byte **)(*(int *)this + 0x38));
  return;
}

