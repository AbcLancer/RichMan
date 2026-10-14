
int __thiscall FUN_00440950(void *this,undefined4 *param_1)

{
  int iVar1;
  int *piVar2;
  int iVar3;
  
  iVar1 = 0;
  if (*(int *)((int)this + 0x40) != 0) {
    iVar3 = 0;
    if (0 < DAT_004f2a10) {
      piVar2 = &DAT_004f1cd0;
      do {
        if (((void *)*piVar2 != (void *)0x0) && ((void *)*piVar2 == this)) {
          *param_1 = piVar2 + -0x70;
          iVar1 = iVar1 + 1;
          param_1 = param_1 + 1;
        }
        iVar3 = iVar3 + 1;
        piVar2 = piVar2 + 0x78;
      } while (iVar3 < DAT_004f2a10);
    }
    return iVar1;
  }
  return iVar1;
}

