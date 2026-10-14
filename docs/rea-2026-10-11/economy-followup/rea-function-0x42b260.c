
int __thiscall FUN_0042b260(void *this,int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int local_4;
  
  iVar2 = 0;
  iVar4 = 0;
  local_4 = 0;
  if (*(int *)((int)this + 0x50) < 1) {
    return 0;
  }
  do {
    iVar3 = *(int *)((int)this + 0x4c);
    iVar5 = 0;
    if (0 < iVar3) {
      do {
        iVar2 = iVar3 * iVar4 + iVar5;
        iVar3 = iVar2 * 0x40 + *(int *)((int)this + 0x54);
        if (((*(byte *)(iVar3 + 0xc) & 2) != 0) && (*(int *)(iVar3 + 0x34) == param_1)) {
          iVar1 = *(int *)(iVar3 + 0x30);
          if ((param_2 < 0) || (2 < param_2)) {
            if (param_2 == 3) {
              if (((iVar1 != 0) && (2 < *(int *)(iVar1 + 0x38))) && (*(int *)(iVar1 + 0x38) < 6))
              goto LAB_0042b2d9;
            }
            else if (iVar1 == 0) goto LAB_0042b2de;
          }
          else if ((iVar1 != 0) && (*(int *)(iVar1 + 0x38) == param_2)) {
LAB_0042b2d9:
            if (iVar2 == *(int *)(iVar3 + 0x14)) {
LAB_0042b2de:
              iVar2 = FUN_0042b450(this,iVar2,0.0);
              local_4 = local_4 + iVar2;
            }
          }
        }
        iVar3 = *(int *)((int)this + 0x4c);
        iVar5 = iVar5 + 1;
        iVar2 = local_4;
      } while (iVar5 < iVar3);
    }
    iVar4 = iVar4 + 1;
    if (*(int *)((int)this + 0x50) <= iVar4) {
      return iVar2;
    }
  } while( true );
}

