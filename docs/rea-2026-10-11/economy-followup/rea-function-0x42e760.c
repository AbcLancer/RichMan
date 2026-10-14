
int __thiscall FUN_0042e720(void *this,int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  
  iVar3 = 0;
  iVar4 = 0;
  if (0 < *(int *)((int)this + 0x28)) {
    iVar2 = 0;
    do {
      iVar1 = FUN_0042b260((void *)(*(int *)((int)this + 0x24) + iVar2),param_1,param_2);
      iVar3 = iVar3 + iVar1;
      iVar4 = iVar4 + 1;
      iVar2 = iVar2 + 0x58;
    } while (iVar4 < *(int *)((int)this + 0x28));
    return iVar3;
  }
  return 0;
}

