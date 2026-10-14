
int __thiscall FUN_0041e420(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar3 = 1;
  iVar2 = 0;
  if (0 < *(int *)(param_1 + 0x30)) {
    do {
      iVar1 = FUN_0041ce10(this,*(int *)(param_1 + 0x38),*(int *)(param_1 + 0x34),iVar3);
      iVar2 = iVar2 + *(int *)(iVar1 + 0x3c);
      iVar3 = iVar3 + 1;
    } while (iVar3 <= *(int *)(param_1 + 0x30));
  }
  return iVar2;
}

