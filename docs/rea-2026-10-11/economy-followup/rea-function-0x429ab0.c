
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00429a70(void *this,double param_1)

{
  double dVar1;
  int iVar2;
  int iVar3;
  void *this_00;
  byte *pbVar4;
  
  if (0 < DAT_004f2a44) {
    iVar2 = FUN_0041a950(&DAT_004e3b28,3);
    iVar3 = FUN_0041a950(&DAT_004e3b28,1);
    if (iVar3 < iVar2 * 10000) {
      FUN_0041aa80(&DAT_004e3b28,1,iVar2 * 10000);
    }
  }
  if (1 < DAT_004f2a44) {
    iVar2 = FUN_0041c2f0(0x4f2a38);
    if ((iVar2 == 0xf) && (DAT_004f2a30 == 0)) {
      _DAT_004fdb20 = 0;
      FUN_0042ab30(&DAT_005090b0,0x3f,(int *)&DAT_004fdb20);
      iVar2 = FUN_00429d20((int)this);
      if (iVar2 != 0) {
        FUN_00429cd0((int)this);
      }
    }
  }
  if ((*(int *)((int)this + 0xd24) != 0) && (*(int *)(*(int *)((int)this + 0xd24) + 0x1c0) == 0)) {
    *(undefined4 *)((int)this + 0xd24) = 0;
  }
  if ((*(int *)((int)this + 0xd24) != 0) &&
     (dVar1 = *(double *)((int)this + 0xd30) - param_1, *(double *)((int)this + 0xd30) = dVar1,
     dVar1 <= 0.0)) {
    iVar2 = FUN_0041a950(&DAT_004e3b28,1);
    if (iVar2 < *(int *)((int)this + 0xd28)) {
      *(int *)((int)this + 0xd28) = iVar2;
    }
    FUN_0041aa80(&DAT_004e3b28,1,iVar2 - *(int *)((int)this + 0xd28));
    pbVar4 = *(byte **)((int)this + 0xd28);
    iVar2 = 0;
    this_00 = (void *)FUN_00435620(*(int *)((int)this + 0xd24));
    FUN_0043ffe0(this_00,pbVar4,iVar2);
    *(undefined4 *)((int)this + 0xd24) = 0;
  }
  return;
}

