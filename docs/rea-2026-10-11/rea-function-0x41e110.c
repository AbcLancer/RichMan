
void __thiscall FUN_0041e110(void *this,uint param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  longlong lVar4;
  char cVar5;
  
  if ((param_2 != 0) && (-1 < (int)param_1)) {
    iVar1 = FUN_0042b1b0(this,param_1);
    iVar3 = *(int *)(iVar1 + 0x30);
    if (iVar3 != 0) {
      if (*(int *)(iVar3 + 0x30) + param_2 < 1) {
        FUN_0041d120(this,iVar1);
        FUN_0041d9e0(this,0);
        lVar4 = __ftol();
        FUN_0043cb00(DAT_004fe7ac,0xcc,
                     (byte *)((uint)((int)this - DAT_004e3844) / 0x58 << 0x10 | param_1),
                     (byte *)lVar4);
        return;
      }
      iVar2 = FUN_0041ce80(&DAT_004ece18,iVar3);
      if (iVar2 < param_2) {
        param_2 = iVar2;
      }
      iVar1 = *(int *)(iVar1 + 0x34);
      cVar5 = '\x01';
      iVar3 = FUN_0041ce10(&DAT_004ece18,*(int *)(iVar3 + 0x38),*(int *)(iVar3 + 0x34),
                           *(int *)(iVar3 + 0x30) + param_2);
      FUN_0041cf40(this,param_1,iVar3,iVar1,cVar5);
      FUN_0041d9e0(this,0);
    }
  }
  return;
}

