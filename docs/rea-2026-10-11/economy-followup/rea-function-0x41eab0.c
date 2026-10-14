
void __thiscall FUN_0041ea80(void *this,int param_1)

{
  int iVar1;
  char *pcVar2;
  
  iVar1 = 0;
  if (0 < *(int *)((int)this + 0x8528)) {
    pcVar2 = (char *)((int)this + 0x6db8);
    do {
      FUN_004026c0(DAT_004a6040,pcVar2,0xc,param_1);
      iVar1 = iVar1 + 1;
      pcVar2 = pcVar2 + 0xc;
    } while (iVar1 < *(int *)((int)this + 0x8528));
  }
  return;
}

