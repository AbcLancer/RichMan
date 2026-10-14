
undefined4 __cdecl FUN_0041fa20(undefined4 param_1,uint param_2,int param_3,int param_4)

{
  int iVar1;
  int iVar2;
  undefined4 *this;
  int iVar3;
  void *this_00;
  
  iVar1 = *(int *)(*(int *)(param_3 + 0xc) + 0x78);
  iVar2 = FUN_0042bb50(iVar1);
  if (*(int *)(iVar2 + 0x30) == 0) {
    return 1;
  }
  this = FUN_00427d70(6,0,0x40080000);
  this[6] = 0;
  this[7] = 0x3ff00000;
  this[0x6d] = param_3;
  iVar3 = FUN_0041ce10(&DAT_004ece18,param_4 % 3 + 3,param_4 / 3 + 1,1);
  FUN_00428520(this,*(void **)(iVar1 + 0x28),*(int *)(iVar1 + 0x2c),iVar3);
  FUN_00428590((int)this);
  iVar1 = *(int *)(iVar2 + 0x34);
  if (iVar1 != 0) {
    iVar2 = FUN_00435620(param_3);
    if (iVar1 != iVar2) {
      this_00 = (void *)FUN_00440170(iVar1);
      FUN_00436810(this_00,param_2,0);
      FUN_0043c5e0(DAT_004fe7ac,0x404,(uint *)(*(int *)(param_3 + 0x38) << 8 | param_2),(int)this_00
                  );
    }
  }
  return 0;
}

