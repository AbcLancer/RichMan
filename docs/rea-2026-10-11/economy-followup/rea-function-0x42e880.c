
void __thiscall FUN_0042e870(void *this,float param_1,int param_2,int param_3)

{
  float *pfVar1;
  float *pfVar2;
  int iVar3;
  float fVar4;
  int iVar5;
  int iVar6;
  void *this_00;
  int local_10;
  int local_c;
  int local_8;
  
  local_c = 0;
  if (0 < *(int *)((int)this + 0x28)) {
    local_8 = 0;
    do {
      this_00 = (void *)(local_8 + *(int *)((int)this + 0x24));
      local_10 = 0;
      if (0 < *(int *)(local_8 + 0x50 + *(int *)((int)this + 0x24))) {
        do {
          iVar6 = 0;
          if (0 < *(int *)((int)this_00 + 0x4c)) {
            do {
              iVar5 = FUN_0042b1c0(this_00,iVar6,local_10);
              if ((param_2 != 0) && (*(int *)(iVar5 + 0x34) != param_2)) goto LAB_0042e945;
              if (param_3 == -1) {
LAB_0042e8f6:
                pfVar1 = (float *)(iVar5 + 0x28);
                fVar4 = ABS(*(float *)(iVar5 + 0x28)) * param_1 + *pfVar1;
                *pfVar1 = fVar4;
                pfVar2 = (float *)(iVar5 + 0x2c);
                *pfVar2 = ABS(fVar4) * param_1 + *pfVar2;
                FUN_0042aea0(pfVar1);
                FUN_0042aea0(pfVar2);
              }
              else {
                iVar3 = *(int *)(iVar5 + 0x30);
                if (iVar3 == 0) {
                  if (param_3 == 4) goto LAB_0042e8f6;
                }
                else if (((2 < param_3) || (*(int *)(iVar3 + 0x38) == param_3)) &&
                        ((param_3 != 3 || (2 < *(int *)(iVar3 + 0x38))))) goto LAB_0042e8f6;
              }
LAB_0042e945:
              iVar6 = iVar6 + 1;
            } while (iVar6 < *(int *)((int)this_00 + 0x4c));
          }
          local_10 = local_10 + 1;
        } while (local_10 < *(int *)((int)this_00 + 0x50));
      }
      local_c = local_c + 1;
      local_8 = local_8 + 0x58;
    } while (local_c < *(int *)((int)this + 0x28));
  }
  return;
}

