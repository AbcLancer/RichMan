
longlong __thiscall FUN_0042b8b0(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  uint extraout_EDX;
  longlong lVar3;
  undefined4 uVar4;
  float local_1c [3];
  undefined4 uStack_10;
  float local_c [3];
  
  iVar1 = FUN_0042b1b0(this,param_1);
  FUN_0042b320(this,param_1,local_1c,local_c);
  iVar1 = *(int *)(iVar1 + 0x30);
  if (iVar1 == 0) {
    local_1c[2] = (float)FUN_0041a950(&DAT_004e1b30,3);
    uStack_10 = 0;
    lVar3 = __ftol();
    return lVar3;
  }
  iVar2 = *(int *)(iVar1 + 0x38);
  if (iVar2 == 0) {
    uVar4 = 5;
  }
  else if (iVar2 == 1) {
    uVar4 = 4;
  }
  else {
    if (iVar2 != 2) {
      return (ulonglong)extraout_EDX << 0x20;
    }
    uVar4 = 6;
  }
  local_1c[2] = (float)FUN_0041a950(&DAT_004e1b30,uVar4);
  iVar2 = FUN_0041a950(&DAT_004e1b30,3);
  local_1c[0] = (float)(iVar2 * *(int *)(iVar1 + 0x40));
  local_1c[1] = 0.0;
  lVar3 = __ftol();
  return lVar3;
}

