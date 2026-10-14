
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_004323c0(void *this,int param_1)

{
  if (*(int *)((int)this + 0x30) != 4) {
    *(int *)((int)this + 0x30) = *(int *)((int)this + 0x30) + 1;
    *(undefined4 *)((int)this + 0x3c) = 0;
    *(byte *)((int)this + 0x40) = *(byte *)((int)this + 0x40) | 2;
    if (param_1 != 0) {
      _DAT_004fdb20 = *(undefined4 *)this;
      _DAT_004fdb24 = *(undefined4 *)this;
      _DAT_004fdb40 = this;
      FUN_0042ab30(&DAT_005090b0,0x9f,(int *)&DAT_004fdb20);
    }
  }
  return;
}

