
int __thiscall FUN_00429ca0(void *this,int param_1,int *param_2)

{
  int iVar1;
  int iVar2;
  
  iVar1 = 0;
  iVar2 = 0;
  do {
    if (*(char *)((int)this + iVar2 + 0xd18) == param_1) {
      *param_2 = iVar2;
      iVar1 = iVar1 + 1;
      param_2 = param_2 + 1;
    }
    iVar2 = iVar2 + 1;
  } while (iVar2 < 0xc);
  return iVar1;
}

