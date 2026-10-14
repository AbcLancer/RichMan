
void __thiscall FUN_00433e20(void *this,int param_1)

{
  bool bVar1;
  int iVar2;
  int iVar3;
  void *pvVar4;
  int iVar5;
  int *piVar6;
  
  iVar2 = param_1;
  iVar5 = DAT_0049e964 * param_1;
  bVar1 = false;
  iVar3 = FUN_00434260(this,&param_1);
  if (iVar3 == 2) {
    if ((param_1 == 1) || (param_1 == 2)) {
      iVar5 = iVar5 * 2;
    }
    else {
      iVar5 = 0;
    }
    if (param_1 == 1) {
      bVar1 = true;
    }
  }
  FUN_00434350(this,iVar5);
  if ((*(int *)((int)this + 0x178) == DAT_0049e96c) && (bVar1)) {
    FUN_004369d0((int)this);
  }
  FUN_00436060(this,2,iVar2);
  FUN_00436060(this,1,iVar2);
  FUN_00436060(this,0xb,iVar2);
  FUN_00436060(this,4,1);
  if (*(int *)((int)this + 0x17c) != -1) {
    iVar5 = iVar2;
    pvVar4 = (void *)FUN_00433040(&DAT_004e3b18,*(int *)((int)this + 0x17c));
    FUN_00431f50(pvVar4,iVar5);
  }
  piVar6 = (int *)((int)this + 0x180);
  iVar5 = 4;
  do {
    if (*piVar6 != -1) {
      iVar3 = iVar2;
      pvVar4 = (void *)FUN_00433040(&DAT_004e3b18,*piVar6);
      FUN_00431f50(pvVar4,iVar3);
    }
    piVar6 = piVar6 + 1;
    iVar5 = iVar5 + -1;
  } while (iVar5 != 0);
  return;
}

