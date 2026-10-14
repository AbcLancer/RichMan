
longlong __thiscall FUN_00440700(void *this,undefined4 param_1)

{
  int iVar1;
  int *piVar2;
  longlong lVar3;
  
  switch(param_1) {
  case 0:
    iVar1 = 0;
    if (0 < *(int *)((int)this + 0x3a4)) {
      do {
        FUN_00440680();
        iVar1 = iVar1 + 1;
      } while (iVar1 < *(int *)((int)this + 0x3a4));
      lVar3 = __ftol();
      return lVar3;
    }
    break;
  case 1:
    iVar1 = 0;
    if (0 < *(int *)((int)this + 0x3a4)) {
      piVar2 = (int *)((int)this + 0x2e4);
      do {
        if ((void *)*piVar2 == this) {
          FUN_00440680();
          lVar3 = __ftol();
          return lVar3;
        }
        iVar1 = iVar1 + 1;
        piVar2 = piVar2 + 2;
      } while (iVar1 < *(int *)((int)this + 0x3a4));
      lVar3 = __ftol();
      return lVar3;
    }
    break;
  case 2:
    iVar1 = 0;
    if (0 < *(int *)((int)this + 0x3a4)) {
      piVar2 = (int *)((int)this + 0x2e4);
      while (((void *)*piVar2 == this || (*(int *)(*piVar2 + 0x48) != 0))) {
        iVar1 = iVar1 + 1;
        piVar2 = piVar2 + 2;
        if (*(int *)((int)this + 0x3a4) <= iVar1) {
          lVar3 = __ftol();
          return lVar3;
        }
      }
      FUN_00440680();
      lVar3 = __ftol();
      return lVar3;
    }
    break;
  case 3:
    iVar1 = 0;
    if (0 < *(int *)((int)this + 0x3a4)) {
      piVar2 = (int *)((int)this + 0x2e4);
      while (*(int *)(*piVar2 + 0x48) == 0) {
        iVar1 = iVar1 + 1;
        piVar2 = piVar2 + 2;
        if (*(int *)((int)this + 0x3a4) <= iVar1) {
          lVar3 = __ftol();
          return lVar3;
        }
      }
      FUN_00440680();
    }
  }
  lVar3 = __ftol();
  return lVar3;
}

