
longlong __thiscall FUN_0042b9c0(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  uint extraout_EDX;
  undefined4 *puVar3;
  longlong lVar4;
  undefined4 uVar5;
  float local_40;
  int local_3c;
  undefined4 uStack_38;
  undefined4 local_34;
  undefined4 uStack_30;
  float local_2c [3];
  undefined4 local_20 [8];
  
  iVar1 = FUN_0042b1b0(this,param_1);
  iVar2 = FUN_00440950(*(void **)(iVar1 + 0x34),local_20);
  local_3c = iVar2;
  if (0 < iVar2) {
    puVar3 = local_20;
    do {
      FUN_00436450((void *)*puVar3);
      puVar3 = puVar3 + 1;
      iVar2 = iVar2 + -1;
    } while (iVar2 != 0);
  }
  FUN_0042b320(this,param_1,&local_40,local_2c);
  if (*(int *)(iVar1 + 0x30) == 0) {
    local_3c = FUN_0041a950(&DAT_004e3b28,3);
    uStack_38 = 0;
    lVar4 = __ftol();
    return lVar4;
  }
  iVar1 = *(int *)(*(int *)(iVar1 + 0x30) + 0x38);
  if (iVar1 == 0) {
    uVar5 = 5;
  }
  else if (iVar1 == 1) {
    uVar5 = 4;
  }
  else {
    if (iVar1 != 2) {
      return (ulonglong)extraout_EDX << 0x20;
    }
    uVar5 = 6;
  }
  local_3c = FUN_0041a950(&DAT_004e3b28,uVar5);
  local_34 = FUN_0041a950(&DAT_004e3b28,3);
  uStack_30 = 0;
  lVar4 = __ftol();
  return lVar4;
}

