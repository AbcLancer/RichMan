
int __thiscall FUN_0042b450(void *this,int param_1,float param_2)

{
  float fVar1;
  int iVar2;
  int iVar3;
  undefined *puVar4;
  longlong lVar5;
  float local_c [3];
  
  fVar1 = param_2;
  puVar4 = &DAT_004c2358;
  if (param_2 == 0.0) {
    puVar4 = &DAT_004ece18;
  }
  FUN_0042b320(this,param_1,&param_2,local_c);
  iVar2 = FUN_0042b1b0(this,param_1);
  if (*(int *)(iVar2 + 0x30) == 0) {
    lVar5 = __ftol();
    iVar3 = (int)lVar5;
  }
  else {
    iVar3 = FUN_0041e420(puVar4,*(int *)(iVar2 + 0x30));
    if (*(int *)(*(int *)(iVar2 + 0x30) + 0x38) != 0) {
      lVar5 = __ftol();
      iVar3 = (int)lVar5;
    }
    lVar5 = __ftol();
    iVar3 = iVar3 + (int)lVar5;
  }
  puVar4 = &DAT_004e1b30;
  if (fVar1 == 0.0) {
    puVar4 = &DAT_004e3b28;
  }
  iVar2 = FUN_0041a950(puVar4,3);
  return iVar2 * iVar3;
}

