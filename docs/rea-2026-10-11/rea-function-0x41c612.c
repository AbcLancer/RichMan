
undefined4 __fastcall FUN_0041c530(void *param_1)

{
  bool bVar1;
  int iVar2;
  void *this;
  int iVar3;
  undefined *puVar4;
  int *piVar5;
  undefined4 local_8;
  int local_4;
  
  if (*(int *)((int)param_1 + 0x17c) == -1) {
    iVar2 = 0;
    piVar5 = (int *)((int)param_1 + 0x180);
    do {
      if (-1 < *piVar5) {
        if (3 < iVar2) {
          return 0;
        }
        FUN_004356c0(param_1,iVar2);
        goto LAB_0041c573;
      }
      iVar2 = iVar2 + 1;
      piVar5 = piVar5 + 1;
    } while (iVar2 < 4);
  }
  else {
LAB_0041c573:
    local_4 = 0;
    this = (void *)FUN_00433040(&DAT_004e3b18,*(int *)((int)param_1 + 0x17c));
    if (*(float *)((int)this + 0x38) == *(float *)((int)this + 0x34)) {
      iVar2 = FUN_00435740(param_1,*(int *)((int)this + 4),*(int *)((int)this + 0x30));
      if (iVar2 != 0) {
        iVar2 = *(int *)((int)this + 4);
        if ((iVar2 == 2) || (iVar2 == 3)) {
          puVar4 = FUN_00436080((int)param_1);
          if (puVar4 == (undefined *)0x0) {
            return 0;
          }
          if (*(int *)(puVar4 + 0x1c0) == 0) {
            return 0;
          }
          iVar2 = FUN_00435400(param_1,puVar4);
          if (iVar2 == 0) {
            return 0;
          }
          local_4 = *(int *)(puVar4 + 0x38);
        }
        else if (iVar2 == 9) {
          iVar2 = FUN_0041f040(&DAT_004e48b8,0xf);
          iVar2 = (**(code **)(iVar2 + 0x224))(param_1,&local_4);
          if (iVar2 == 0) {
            return 0;
          }
        }
        else if ((iVar2 == 7) &&
                (iVar2 = FUN_0042bb50(*(int *)(*(int *)((int)param_1 + 0xc) + 0x78)),
                *(int *)(iVar2 + 0x34) != *(int *)((int)param_1 + 0x1c0))) {
          return 0;
        }
        FUN_00435910(param_1,local_4);
        return 1;
      }
    }
    else {
      local_8 = 0xffffffff;
      bVar1 = true;
      iVar2 = 0;
      do {
        iVar3 = FUN_00434620(param_1,iVar2);
        if (iVar3 < 0) {
          bVar1 = false;
        }
        else {
          local_8 = FUN_00434620(param_1,iVar2);
        }
        iVar2 = iVar2 + 1;
      } while (iVar2 < 5);
      if ((-1 < (short)local_8) && ((bVar1 || (*(float *)((int)this + 0x38) < 2.0)))) {
        iVar2 = FUN_0041f060(&DAT_004e48b8,(int)(short)local_8);
        iVar2 = FUN_0041f040(&DAT_004e48b8,*(int *)(iVar2 + 4));
        FUN_00432410(this,*(int *)(iVar2 + 0x11c));
        FUN_00434c40(param_1,1,(short *)&local_8,0);
        return 0;
      }
    }
  }
  return 0;
}

