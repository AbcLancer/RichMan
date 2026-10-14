
int __thiscall FUN_00434f40(void *this,int param_1)

{
  int iVar1;
  int *piVar2;
  
  iVar1 = 0;
  piVar2 = (int *)((int)this + 0x84);
  while ((piVar2[5] == 0 || (*piVar2 != param_1))) {
    iVar1 = iVar1 + 1;
    piVar2 = piVar2 + 7;
    if (4 < iVar1) {
      return -1;
    }
  }
  return iVar1;
}

