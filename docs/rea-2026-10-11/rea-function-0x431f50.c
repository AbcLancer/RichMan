
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00431f50(void *this,int param_1)

{
  float fVar1;
  int iVar2;
  
  *(int *)((int)this + 0x18) = *(int *)((int)this + 0x18) + param_1;
  iVar2 = FUN_00435630(*(void **)this,0xff);
  if (iVar2 == *(int *)((int)this + 0x50)) {
    if (*(float *)((int)this + 0x38) < *(float *)((int)this + 0x34)) {
      fVar1 = *(float *)((int)this + 0x38);
      iVar2 = DAT_00508f10 * 0x18;
      *(byte *)((int)this + 0x40) = *(byte *)((int)this + 0x40) | 1;
      *(float *)((int)this + 0x38) = *(float *)((int)this + 0x38) - (float)param_1 / (float)iVar2;
      if (((*(float *)((int)this + 0x38) < 1.0) && (0.0 < *(float *)((int)this + 0x38))) &&
         (1.0 <= fVar1)) {
        _DAT_004fdb20 = *(undefined4 *)this;
        _DAT_004fdb40 = this;
        FUN_0042ab30(&DAT_005090b0,0x9a,(int *)&DAT_004fdb20);
      }
    }
    if (*(float *)((int)this + 0x38) <= 0.0) {
      FUN_004320b0(this);
      return;
    }
    if (*(int *)((int)this + 0x30) * DAT_00508f14 <= *(int *)((int)this + 0x3c)) {
      FUN_004323c0(this,1);
    }
    FUN_00432130((int)this);
    if ((*(int *)((int)this + 0x38) == 0x3f800000) && (iVar2 = FUN_00405130(0,0x30), iVar2 == 1)) {
      FUN_00432d60(this,5);
      return;
    }
    if ((*(float *)((int)this + 0x38) < 3.0) && (iVar2 = FUN_00405130(0,0x30), iVar2 == 1)) {
      FUN_00432d60(this,3);
      return;
    }
    iVar2 = FUN_00405130(0,0x60);
    if (iVar2 == 1) {
      FUN_00432d60(this,2);
    }
  }
  return;
}

