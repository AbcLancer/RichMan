
undefined4 __thiscall FUN_0041f080(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  
  iVar1 = FUN_0041f060(this,param_1);
  iVar2 = FUN_0041f040(this,*(int *)(iVar1 + 4));
  if (*(int *)(iVar2 + 0x13c) == 999) {
    *(uint *)(iVar1 + 8) = *(uint *)(iVar1 + 8) | 1;
    return *(undefined4 *)(iVar2 + 0x13c);
  }
  FUN_0041f0e0(this,param_1,*(int *)(iVar2 + 0x13c));
  return *(undefined4 *)(iVar2 + 0x13c);
}

