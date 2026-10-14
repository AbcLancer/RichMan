
void __thiscall FUN_00436840(void *this,uint param_1,uint param_2,int param_3)

{
  int iVar1;
  int *piVar2;
  char *pcVar3;
  int iVar4;
  int iVar5;
  int local_30 [3];
  void *local_24 [9];
  
  iVar1 = param_1 + 1;
  FUN_00436990((int)this,iVar1,param_2);
  if (param_3 != 0) {
    local_30[0] = 0;
    local_30[1] = 0;
    local_30[2] = 0;
    FUN_004232e0(*(void **)((int)this + 0xc),local_30);
    if (param_2 == 0) {
      FUN_0043e3b0(*(int *)((int)this + 0x30),2,param_1,local_30,0.0);
      return;
    }
    FUN_0043e3b0(*(int *)((int)this + 0x30),1,param_1,local_30,0.0);
    return;
  }
  iVar5 = *(int *)((int)this + 0x30);
  if (iVar5 < 10) {
    iVar5 = iVar5 * 100 + 0x1b59;
  }
  else {
    iVar5 = iVar5 * 100 + 0x1bbd;
  }
  if (param_2 == 0) {
    iVar4 = 0;
    piVar2 = &DAT_0049e9d4;
    do {
      if (iVar1 == *piVar2) {
        if (iVar4 < 0xc) {
          iVar5 = iVar5 + 0x32 + iVar4;
          goto LAB_00436931;
        }
        break;
      }
      piVar2 = piVar2 + 1;
      iVar4 = iVar4 + 1;
    } while ((int)piVar2 < 0x49ea04);
    FUN_00401050((byte *)s_selftalkoncard___error__cardinfo_0049ea30);
  }
  else {
    if ((8 < iVar1) && (iVar1 < 0xe)) {
      return;
    }
    if ((0x1f < iVar1) && (iVar1 < 0x22)) {
      return;
    }
    iVar5 = iVar5 + -1 + iVar1;
  }
LAB_00436931:
  local_24[0] = this;
  piVar2 = (int *)FUN_0042a8a0(&DAT_005090b0,iVar5);
  pcVar3 = (char *)FUN_0042a940(piVar2,(int)local_24);
  FUN_0042ae10(PTR_DAT_0049cf30,1,pcVar3,
               ((param_2 | 2) << 0xd | *(uint *)((int)this + 0x38)) << 0x10 | param_1,0);
  return;
}

