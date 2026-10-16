// ===== 4213c0 → FUN_004213c0 @ 004213c0（就是入口）  大小 150 字节

undefined4 __cdecl FUN_004213c0(void *param_1,int *param_2)

{
  undefined4 uVar1;
  bool bVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  undefined3 extraout_var;
  
  iVar3 = FUN_00436230(param_1,3);
  if (iVar3 != 0) {
    uVar1 = *(undefined4 *)(*(int *)((int)param_1 + 0xc) + 0x74);
    iVar3 = 1;
    do {
      *param_2 = iVar3;
      iVar4 = FUN_0042bb70(uVar1,1);
      iVar5 = *(int *)(iVar4 + 0x30);
      if (iVar5 == 4) {
        return 1;
      }
      if (iVar5 == 0x10) {
        return 1;
      }
      if (iVar5 == 7) {
        return 1;
      }
      iVar5 = FUN_0042bb50(iVar4);
      if (iVar5 != 0) {
        if (*(int *)(iVar5 + 0x34) == 0) {
          return 1;
        }
        iVar4 = FUN_00435620((int)param_1);
        if (*(int *)(iVar5 + 0x34) == iVar4) {
          if (*(int *)(iVar5 + 0x30) == 0) {
            return 1;
          }
          bVar2 = FUN_0041ce40(&DAT_004ece18,*(int *)(iVar5 + 0x30));
          if (CONCAT31(extraout_var,bVar2) != 0) {
            return 1;
          }
        }
      }
      iVar3 = iVar3 + 1;
    } while (iVar3 < 6);
  }
  return 0;
}



// ===== 41f9e0 → FUN_0041f9e0 @ 0041f9e0（就是入口）  大小 63 字节

undefined4 __cdecl FUN_0041f9e0(undefined4 param_1,undefined4 param_2,byte *param_3,byte *param_4)

{
  int iVar1;
  
  iVar1 = FUN_00436230(param_3,3);
  if (iVar1 == 0) {
    return 2;
  }
  FUN_00435510(param_3);
  FUN_00434270(param_3,3);
  FUN_00439bf0((undefined4 *)0x3,param_4,param_3);
  return 0;
}



// ===== 421760 → 不是已识别函数（可能只被函数指针引用）→ 改为线性反汇编

00421760  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421764  MOV                    MOV EAX,dword ptr [EAX + 0xc]
00421767  MOV                    MOV EDX,dword ptr [EAX + 0x74]
0042176a  XOR                    XOR ECX,ECX
0042176c  TEST                   TEST EDX,EDX
0042176e  PUSH                   PUSH EBX
0042176f  SETZ                   SETZ CL
00421772  PUSH                   PUSH EBP
00421773  PUSH                   PUSH ESI
00421774  PUSH                   PUSH EDI
00421775  MOV                    MOV EDI,dword ptr [EAX + 0x78]
00421778  XOR                    XOR EBX,EBX
0042177a  MOV                    MOV EBP,ECX
0042177c  PUSH                   PUSH 0x1
0042177e  PUSH                   PUSH EBP
0042177f  MOV                    MOV ECX,EDI
00421781  CALL                   CALL 0x0042bb70
00421786  MOV                    MOV EDI,EAX
00421788  CMP                    CMP dword ptr [EDI + 0x34],-0x1
0042178c  JNZ                    JNZ 0x004217d3
0042178e  MOV                    MOV ECX,EDI
00421790  CALL                   CALL 0x0042bf50
00421795  TEST                   TEST EAX,EAX
00421797  JNZ                    JNZ 0x004217d3
00421799  MOV                    MOV ECX,EDI
0042179b  CALL                   CALL 0x0042bb50
004217a0  MOV                    MOV ESI,EAX
004217a2  TEST                   TEST ESI,ESI
004217a4  JZ                     JZ 0x004217d3
004217a6  MOV                    MOV EAX,dword ptr [ESI + 0x30]
004217a9  TEST                   TEST EAX,EAX
004217ab  JZ                     JZ 0x004217d3
004217ad  MOV                    MOV ECX,dword ptr [ESP + 0x14]
004217b1  CALL                   CALL 0x00435620
004217b6  CMP                    CMP dword ptr [ESI + 0x34],EAX
004217b9  JNZ                    JNZ 0x004217d3
004217bb  MOV                    MOV ESI,dword ptr [ESI + 0x30]
004217be  CMP                    CMP dword ptr [ESI + 0x34],0x3
004217c2  JZ                     JZ 0x004217e0
004217c4  PUSH                   PUSH ESI
004217c5  MOV                    MOV ECX,0x4ece18
004217ca  CALL                   CALL 0x0041ce40
004217cf  TEST                   TEST EAX,EAX
004217d1  JZ                     JZ 0x004217e0
004217d3  INC                    INC EBX
004217d4  CMP                    CMP EBX,0x5
004217d7  JLE                    JLE 0x0042177c
004217d9  POP                    POP EDI
004217da  POP                    POP ESI
004217db  POP                    POP EBP
004217dc  XOR                    XOR EAX,EAX
004217de  POP                    POP EBX
004217df  RET                    RET
004217e0  MOV                    MOV EDX,dword ptr [EDI + 0xc]
004217e3  MOV                    MOV EAX,dword ptr [ESP + 0x18]
004217e7  POP                    POP EDI
004217e8  POP                    POP ESI
004217e9  POP                    POP EBP
004217ea  MOV                    MOV dword ptr [EAX],EDX
004217ec  MOV                    MOV EAX,0x1
004217f1  POP                    POP EBX
004217f2  RET                    RET
00421800  MOV                    MOV ECX,dword ptr [ESP + 0x4]
00421804  CALL                   CALL 0x00435620
00421809  MOV                    MOV EDX,dword ptr [EAX + 0x4c]
0042180c  XOR                    XOR ECX,ECX
0042180e  CMP                    CMP EDX,0x249f0
00421814  SETL                   SETL CL
00421817  MOV                    MOV EAX,ECX
00421819  RET                    RET
00421820  SUB                    SUB ESP,0x28
00421823  PUSH                   PUSH ESI
00421824  MOV                    MOV ESI,dword ptr [ESP + 0x30]
00421828  PUSH                   PUSH EDI
00421829  MOV                    MOV ECX,ESI
0042182b  CALL                   CALL 0x00436080
00421830  MOV                    MOV EDI,EAX
00421832  MOV                    MOV EAX,dword ptr [ESI + 0xc]
00421835  MOV                    MOV EAX,dword ptr [EAX + 0x78]
00421838  PUSH                   PUSH EAX
00421839  PUSH                   PUSH 0x40e00000
0042183e  PUSH                   PUSH 0x0
00421840  LEA                    LEA ECX,[ESP + 0x14]
00421844  PUSH                   PUSH ECX
00421845  MOV                    MOV ECX,0x4f1b08
0042184a  CALL                   CALL 0x0043a6a0
0042184f  XOR                    XOR ECX,ECX
00421851  TEST                   TEST EAX,EAX
00421853  JLE                    JLE 0x00421865
00421855  LEA                    LEA EDX,[ESP + 0x8]
00421859  CMP                    CMP dword ptr [EDX],EDI
0042185b  JZ                     JZ 0x0042186d
0042185d  INC                    INC ECX
0042185e  ADD                    ADD EDX,0x4
00421861  CMP                    CMP ECX,EAX
00421863  JL                     JL 0x00421859
00421865  POP                    POP EDI
00421866  XOR                    XOR EAX,EAX
00421868  POP                    POP ESI
00421869  ADD                    ADD ESP,0x28
0042186c  RET                    RET
0042186d  POP                    POP EDI
0042186e  MOV                    MOV EAX,0x1
00421873  POP                    POP ESI
00421874  ADD                    ADD ESP,0x28
00421877  RET                    RET
00421880  SUB                    SUB ESP,0x10
00421883  MOV                    MOV EAX,dword ptr [ESP + 0x14]
00421887  PUSH                   PUSH EBX
00421888  PUSH                   PUSH EBP
00421889  PUSH                   PUSH ESI
0042188a  PUSH                   PUSH EDI
0042188b  PUSH                   PUSH EAX
0042188c  CALL                   CALL 0x00421980
00421891  MOV                    MOV ESI,EAX
00421893  XOR                    XOR EBP,EBP
00421895  ADD                    ADD ESP,0x4
00421898  CMP                    CMP ESI,EBP
0042189a  MOV                    MOV dword ptr [ESP + 0x14],ESI
0042189e  JNZ                    JNZ 0x004218aa
004218a0  POP                    POP EDI
004218a1  POP                    POP ESI
004218a2  POP                    POP EBP
004218a3  XOR                    XOR EAX,EAX
004218a5  POP                    POP EBX
004218a6  ADD                    ADD ESP,0x10
004218a9  RET                    RET
004218aa  CMP                    CMP dword ptr [0x004f2a30],EBP
004218b0  JNZ                    JNZ 0x00421964
004218b6  MOV                    MOV EDX,dword ptr [ESI + 0xc]
004218b9  MOV                    MOV EAX,dword ptr [EDX + 0x78]
004218bc  MOV                    MOV dword ptr [ESP + 0x1c],EAX
004218c0  MOV                    MOV dword ptr [ESP + 0x18],EAX
004218c4  MOV                    MOV EAX,[0x00508e78]
004218c9  CDQ                    CDQ
004218ca  SUB                    SUB EAX,EDX
004218cc  SAR                    SAR EAX,0x1
004218ce  TEST                   TEST EAX,EAX
004218d0  MOV                    MOV dword ptr [ESP + 0x10],EBP
004218d4  JLE                    JLE 0x00421949
004218d6  XOR                    XOR EBX,EBX
004218d8  LEA                    LEA EDI,[ESP + 0x18]
004218dc  MOV                    MOV ECX,dword ptr [EDI]
004218de  PUSH                   PUSH 0x1
004218e0  PUSH                   PUSH EBX
004218e1  CALL                   CALL 0x0042bb70
004218e6  MOV                    MOV ECX,EAX
004218e8  MOV                    MOV dword ptr [EDI],EAX
004218ea  CALL                   CALL 0x0042bb50
004218ef  MOV                    MOV ESI,EAX
004218f1  TEST                   TEST ESI,ESI
004218f3  JZ                     JZ 0x00421921
004218f5  MOV                    MOV EAX,dword ptr [ESI + 0x30]
004218f8  TEST                   TEST EAX,EAX
004218fa  JZ                     JZ 0x0042190a
004218fc  MOV                    MOV ECX,dword ptr [ESP + 0x24]
00421900  CALL                   CALL 0x00435620
00421905  CMP                    CMP dword ptr [ESI + 0x34],EAX
00421908  JZ                     JZ 0x0042195a
0042190a  MOV                    MOV EAX,dword ptr [ESI + 0x30]
0042190d  PUSH                   PUSH EAX
0042190e  MOV                    MOV ECX,0x4ece18
00421913  CALL                   CALL 0x0041ce40
00421918  TEST                   TEST EAX,EAX
0042191a  JNZ                    JNZ 0x00421921
0042191c  MOV                    MOV EBP,0x1
00421921  INC                    INC EBX
00421922  ADD                    ADD EDI,0x4
00421925  CMP                    CMP EBX,0x2
00421928  JL                     JL 0x004218dc
0042192a  MOV                    MOV EAX,[0x00508e78]
0042192f  MOV                    MOV ECX,dword ptr [ESP + 0x10]
00421933  CDQ                    CDQ
00421934  SUB                    SUB EAX,EDX
00421936  INC                    INC ECX
00421937  SAR                    SAR EAX,0x1
00421939  CMP                    CMP ECX,EAX
0042193b  MOV                    MOV dword ptr [ESP + 0x10],ECX
0042193f  JL                     JL 0x004218d6
00421941  TEST                   TEST EBP,EBP
00421943  MOV                    MOV ESI,dword ptr [ESP + 0x14]
00421947  JNZ                    JNZ 0x00421964
00421949  PUSH                   PUSH 0x64
0042194b  PUSH                   PUSH 0x0
0042194d  CALL                   CALL 0x00405130
00421952  ADD                    ADD ESP,0x8
00421955  CMP                    CMP EAX,0x32
00421958  JLE                    JLE 0x00421964
0042195a  POP                    POP EDI
0042195b  POP                    POP ESI
0042195c  POP                    POP EBP
0042195d  XOR                    XOR EAX,EAX
0042195f  POP                    POP EBX
00421960  ADD                    ADD ESP,0x10
00421963  RET                    RET
00421964  MOV                    MOV ECX,dword ptr [ESI + 0xc]
00421967  MOV                    MOV EDX,dword ptr [ECX + 0x78]
0042196a  MOV                    MOV EAX,dword ptr [EDX + 0xc]
0042196d  MOV                    MOV ECX,dword ptr [ESP + 0x28]
00421971  POP                    POP EDI
00421972  POP                    POP ESI
00421973  POP                    POP EBP
00421974  MOV                    MOV dword ptr [ECX],EAX
00421976  MOV                    MOV EAX,0x1
0042197b  POP                    POP EBX
0042197c  ADD                    ADD ESP,0x10
0042197f  RET                    RET
00421980  SUB                    SUB ESP,0x30
00421983  PUSH                   PUSH EBX
00421984  MOV                    MOV EBX,dword ptr [ESP + 0x38]
00421988  MOV                    MOV ECX,dword ptr [EBX + 0xc]
0042198b  PUSH                   PUSH ESI
0042198c  PUSH                   PUSH EDI
0042198d  LEA                    LEA EAX,[ESP + 0xc]
00421991  PUSH                   PUSH EAX
00421992  PUSH                   PUSH 0x0
00421994  MOV                    MOV dword ptr [ESP + 0x14],0x0
0042199c  MOV                    MOV dword ptr [ESP + 0x18],0x0
004219a4  MOV                    MOV dword ptr [ESP + 0x1c],0x0
004219ac  MOV                    MOV dword ptr [ESP + 0x20],0x0
004219b4  MOV                    MOV dword ptr [ESP + 0x24],0x0
004219bc  MOV                    MOV dword ptr [ESP + 0x28],0x0
004219c4  MOV                    MOV dword ptr [ESP + 0x2c],0x0
004219cc  MOV                    MOV dword ptr [ESP + 0x30],0x0
004219d4  MOV                    MOV dword ptr [ESP + 0x34],0x0
004219dc  MOV                    MOV ECX,dword ptr [ECX + 0x78]
004219df  PUSH                   PUSH 0x0
004219e1  CALL                   CALL 0x0042bd30
004219e6  MOV                    MOV EAX,[0x004f2a10]
004219eb  XOR                    XOR EDI,EDI
004219ed  TEST                   TEST EAX,EAX
004219ef  JLE                    JLE 0x00421aca
004219f5  MOV                    MOV ESI,0x4f1b10
004219fa  MOV                    MOV EDX,dword ptr [ESI + 0x1c0]
00421a00  CMP                    CMP EDX,dword ptr [EBX + 0x1c0]
00421a06  JZ                     JZ 0x00421ab6
00421a0c  MOV                    MOV EAX,dword ptr [ESI + 0xc]
00421a0f  MOV                    MOV ECX,dword ptr [EAX + 0x98]
00421a15  TEST                   TEST ECX,ECX
00421a17  JZ                     JZ 0x00421ab6
00421a1d  MOV                    MOV ECX,ESI
00421a1f  CALL                   CALL 0x004364a0
00421a24  TEST                   TEST EAX,EAX
00421a26  JZ                     JZ 0x00421ab6
00421a2c  PUSH                   PUSH 0x1
00421a2e  MOV                    MOV ECX,ESI
00421a30  CALL                   CALL 0x00435fe0
00421a35  TEST                   TEST EAX,EAX
00421a37  JNZ                    JNZ 0x00421ab6
00421a39  MOV                    MOV EDX,dword ptr [ESI + 0xc]
00421a3c  LEA                    LEA ECX,[ESP + 0x18]
00421a40  PUSH                   PUSH ECX
00421a41  MOV                    MOV ECX,dword ptr [EDX + 0x78]
00421a44  PUSH                   PUSH EAX
00421a45  PUSH                   PUSH EAX
00421a46  CALL                   CALL 0x0042bd30
00421a4b  FLD                    FLD float ptr [ESP + 0xc]
00421a4f  FSUB                   FSUB float ptr [ESP + 0x18]
00421a53  FLD                    FLD float ptr [ESP + 0x10]
00421a57  FSUB                   FSUB float ptr [ESP + 0x1c]
00421a5b  FSTP                   FSTP float ptr [ESP + 0x34]
00421a5f  FLD                    FLD float ptr [ESP + 0x14]
00421a63  MOV                    MOV EAX,dword ptr [ESP + 0x34]
00421a67  FSUB                   FSUB float ptr [ESP + 0x20]
00421a6b  MOV                    MOV dword ptr [ESP + 0x28],EAX
00421a6f  FSTP                   FSTP float ptr [ESP + 0x38]
00421a73  MOV                    MOV ECX,dword ptr [ESP + 0x38]
00421a77  MOV                    MOV dword ptr [ESP + 0x2c],ECX
00421a7b  FSTP                   FSTP float ptr [ESP + 0x24]
00421a7f  LEA                    LEA ECX,[ESP + 0x24]
00421a83  CALL                   CALL 0x00403e20
00421a88  FDIV                   FDIV float ptr [0x00495b50]
00421a8e  FCOM                   FCOM float ptr [0x00495474]
00421a94  FNSTSW                 FNSTSW AX
00421a96  TEST                   TEST AH,0x1
00421a99  JZ                     JZ 0x00421ab4
00421a9b  FILD                   FILD dword ptr [0x00508e78]
00421aa1  FMUL                   FMUL float ptr [0x00495490]
00421aa7  FXCH                   FXCH
00421aa9  FCOMPP                 FCOMPP
00421aab  FNSTSW                 FNSTSW AX
00421aad  TEST                   TEST AH,0x41
00421ab0  JZ                     JZ 0x00421ad3
00421ab2  JMP                    JMP 0x00421ab6
00421ab4  FSTP                   FSTP ST0
00421ab6  MOV                    MOV EAX,[0x004f2a10]
00421abb  INC                    INC EDI
00421abc  ADD                    ADD ESI,0x1e0
00421ac2  CMP                    CMP EDI,EAX
00421ac4  JL                     JL 0x004219fa
00421aca  POP                    POP EDI
00421acb  POP                    POP ESI
00421acc  XOR                    XOR EAX,EAX
00421ace  POP                    POP EBX
00421acf  ADD                    ADD ESP,0x30
00421ad2  RET                    RET
00421ad3  POP                    POP EDI
00421ad4  MOV                    MOV EAX,ESI
00421ad6  POP                    POP ESI
00421ad7  POP                    POP EBX
00421ad8  ADD                    ADD ESP,0x30
00421adb  RET                    RET
00421ae0  PUSH                   PUSH 0x3
00421ae2  PUSH                   PUSH 0x1
00421ae4  CALL                   CALL 0x00405130
00421ae9  ADD                    ADD ESP,0x8
00421aec  DEC                    DEC EAX
00421aed  NEG                    NEG EAX
00421aef  SBB                    SBB EAX,EAX
00421af1  INC                    INC EAX
00421af2  RET                    RET
00421b00  MOV                    MOV EAX,[0x004e3b74]
00421b05  TEST                   TEST EAX,EAX
00421b07  JZ                     JZ 0x00421b0c
00421b09  XOR                    XOR EAX,EAX
00421b0b  RET                    RET
00421b0c  PUSH                   PUSH ESI
00421b0d  MOV                    MOV ESI,dword ptr [ESP + 0x8]
00421b11  PUSH                   PUSH EDI
00421b12  MOV                    MOV ECX,ESI
00421b14  CALL                   CALL 0x00435620
00421b19  MOV                    MOV EDI,dword ptr [EAX + 0x44]
00421b1c  MOV                    MOV ECX,ESI
00421b1e  CALL                   CALL 0x00435620
00421b23  MOV                    MOV ECX,EAX
00421b25  CALL                   CALL 0x004406b0
00421b2a  MOV                    MOV ESI,dword ptr [EAX + 0x44]
00421b2d  PUSH                   PUSH 0x2
00421b2f  PUSH                   PUSH 0x1
00421b31  CALL                   CALL 0x00405130
00421b36  ADD                    ADD ESP,0x8
00421b39  CMP                    CMP EAX,0x1
00421b3c  JNZ                    JNZ 0x00421b4c
00421b3e  MOV                    MOV EAX,dword ptr [ESP + 0x10]
00421b42  MOV                    MOV dword ptr [EAX],EDI
00421b44  POP                    POP EDI
00421b45  MOV                    MOV EAX,0x1
00421b4a  POP                    POP ESI
00421b4b  RET                    RET
00421b4c  MOV                    MOV ECX,dword ptr [ESP + 0x10]
00421b50  POP                    POP EDI
00421b51  MOV                    MOV dword ptr [ECX],ESI
00421b53  MOV                    MOV EAX,0x1
00421b58  POP                    POP ESI
00421b59  RET                    RET
00421b60  MOV                    MOV EAX,[0x004e3b74]
00421b65  TEST                   TEST EAX,EAX
00421b67  PUSH                   PUSH EBX
00421b68  PUSH                   PUSH EBP
00421b69  JNZ                    JNZ 0x00421c82
00421b6f  MOV                    MOV ECX,dword ptr [ESP + 0xc]
00421b73  CALL                   CALL 0x00436080
00421b78  TEST                   TEST EAX,EAX
00421b7a  JZ                     JZ 0x00421c82
00421b80  MOV                    MOV ECX,dword ptr [EAX + 0x1c0]
00421b86  TEST                   TEST ECX,ECX
00421b88  JZ                     JZ 0x00421c82
00421b8e  PUSH                   PUSH ESI
00421b8f  PUSH                   PUSH EDI
00421b90  MOV                    MOV ECX,EAX
00421b92  CALL                   CALL 0x00435620
00421b97  MOV                    MOV ECX,EAX
00421b99  CALL                   CALL 0x004406b0
00421b9e  MOV                    MOV EBP,EAX
00421ba0  MOV                    MOV EAX,[0x004e3b50]
00421ba5  XOR                    XOR EDI,EDI
00421ba7  OR                     OR EBX,0xffffffff
00421baa  XOR                    XOR ESI,ESI
00421bac  TEST                   TEST EAX,EAX
00421bae  JLE                    JLE 0x00421bda
00421bb0  PUSH                   PUSH ESI
00421bb1  MOV                    MOV ECX,0x4e3b48
00421bb6  CALL                   CALL 0x00441000
00421bbb  MOV                    MOV ECX,dword ptr [EAX + 0x40]
00421bbe  TEST                   TEST ECX,ECX
00421bc0  JZ                     JZ 0x00421bd0
00421bc2  MOV                    MOV EAX,dword ptr [EAX + 0x2dc]
00421bc8  CMP                    CMP EDI,EAX
00421bca  JGE                    JGE 0x00421bd0
00421bcc  MOV                    MOV EDI,EAX
00421bce  MOV                    MOV EBX,ESI
00421bd0  MOV                    MOV EAX,[0x004e3b50]
00421bd5  INC                    INC ESI
00421bd6  CMP                    CMP ESI,EAX
00421bd8  JL                     JL 0x00421bb0
00421bda  PUSH                   PUSH 0x3
00421bdc  PUSH                   PUSH 0x1
00421bde  CALL                   CALL 0x00405130
00421be3  ADD                    ADD ESP,0x8
00421be6  DEC                    DEC EAX
00421be7  POP                    POP EDI
00421be8  POP                    POP ESI
00421be9  JZ                     JZ 0x00421c5c
00421beb  DEC                    DEC EAX
00421bec  JZ                     JZ 0x00421c1b
00421bee  DEC                    DEC EAX
00421bef  JNZ                    JNZ 0x00421c7a
00421bf5  MOV                    MOV ECX,dword ptr [ESP + 0xc]
00421bf9  CALL                   CALL 0x00435620
00421bfe  PUSH                   PUSH EAX


// ===== 41ffa0 → 不是已识别函数（可能只被函数指针引用）→ 改为线性反汇编

0041ffa0  MOV                    MOV EAX,dword ptr [ESP + 0x10]
0041ffa4  MOV                    MOV EDX,dword ptr [0x004e3834]
0041ffaa  MOV                    MOV ECX,EAX
0041ffac  SHL                    SHL ECX,0x4
0041ffaf  ADD                    ADD ECX,EAX
0041ffb1  MOV                    MOV EAX,dword ptr [EDX + ECX*0x4 + 0x34]
0041ffb5  TEST                   TEST EAX,EAX
0041ffb7  LEA                    LEA ECX,[EDX + ECX*0x4]
0041ffba  JL                     JL 0x0041ffc2
0041ffbc  MOV                    MOV EAX,0x1
0041ffc1  RET                    RET
0041ffc2  PUSH                   PUSH 0x8
0041ffc4  CALL                   CALL 0x0042be00
0041ffc9  TEST                   TEST EAX,EAX
0041ffcb  JGE                    JGE 0x0041ffd3
0041ffcd  MOV                    MOV EAX,0x1
0041ffd2  RET                    RET
0041ffd3  MOV                    MOV EAX,dword ptr [ESP + 0xc]
0041ffd7  MOV                    MOV ECX,dword ptr [EAX + 0xc]
0041ffda  MOV                    MOV EDX,dword ptr [ECX + 0x78]
0041ffdd  PUSH                   PUSH EDX
0041ffde  PUSH                   PUSH 0x25
0041ffe0  CALL                   CALL 0x0042f9b0
0041ffe5  ADD                    ADD ESP,0x8
0041ffe8  XOR                    XOR EAX,EAX
0041ffea  RET                    RET
0041fff0  MOV                    MOV ECX,dword ptr [ESP + 0x4]
0041fff4  TEST                   TEST ECX,ECX
0041fff6  MOV                    MOV EAX,0x1
0041fffb  JZ                     JZ 0x00420002
0041fffd  MOV                    MOV EAX,0x2
00420002  MOV                    MOV ECX,dword ptr [0x00508e70]
00420008  IMUL                   IMUL ECX,EAX
0042000b  PUSH                   PUSH ECX
0042000c  MOV                    MOV ECX,dword ptr [ESP + 0x10]
00420010  PUSH                   PUSH 0x0
00420012  CALL                   CALL 0x00435f80
00420017  XOR                    XOR EAX,EAX
00420019  RET                    RET
00420020  MOV                    MOV ECX,dword ptr [ESP + 0x4]
00420024  TEST                   TEST ECX,ECX
00420026  MOV                    MOV EAX,0x1
0042002b  JZ                     JZ 0x00420032
0042002d  MOV                    MOV EAX,0x2
00420032  MOV                    MOV ECX,dword ptr [0x00508e74]
00420038  IMUL                   IMUL ECX,EAX
0042003b  PUSH                   PUSH ESI
0042003c  MOV                    MOV ESI,dword ptr [ESP + 0x10]
00420040  PUSH                   PUSH ECX
00420041  PUSH                   PUSH 0x1
00420043  MOV                    MOV ECX,ESI
00420045  CALL                   CALL 0x00435f80
0042004a  PUSH                   PUSH 0x4fdb20
0042004f  PUSH                   PUSH 0x3f5
00420054  MOV                    MOV ECX,0x5090b0
00420059  MOV                    MOV dword ptr [0x004fdb20],ESI
0042005f  CALL                   CALL 0x0042ab30
00420064  MOV                    MOV EDX,dword ptr [ESI + 0xc]
00420067  MOV                    MOV EAX,dword ptr [EDX + 0x78]
0042006a  PUSH                   PUSH EAX
0042006b  PUSH                   PUSH 0x26
0042006d  CALL                   CALL 0x0042f9b0
00420072  ADD                    ADD ESP,0x8
00420075  XOR                    XOR EAX,EAX
00420077  POP                    POP ESI
00420078  RET                    RET
00420080  MOV                    MOV EDX,dword ptr [0x004e3834]
00420086  PUSH                   PUSH EBX
00420087  PUSH                   PUSH EBP
00420088  PUSH                   PUSH ESI
00420089  PUSH                   PUSH EDI
0042008a  MOV                    MOV EDI,dword ptr [ESP + 0x1c]
0042008e  MOV                    MOV EAX,dword ptr [EDI + 0xc]
00420091  MOV                    MOV EBP,dword ptr [EAX + 0x78]
00420094  MOV                    MOV EAX,dword ptr [ESP + 0x20]
00420098  MOV                    MOV ECX,EAX
0042009a  PUSH                   PUSH 0x40000000
0042009f  SHL                    SHL ECX,0x4
004200a2  ADD                    ADD ECX,EAX
004200a4  PUSH                   PUSH 0x0
004200a6  PUSH                   PUSH 0x7
004200a8  LEA                    LEA EBX,[EDX + ECX*0x4]
004200ab  CALL                   CALL 0x00427d70
004200b0  ADD                    ADD ESP,0xc
004200b3  PUSH                   PUSH EDI
004200b4  MOV                    MOV ESI,EAX
004200b6  PUSH                   PUSH 0x3f800000
004200bb  PUSH                   PUSH EBX
004200bc  MOV                    MOV dword ptr [ESI + 0x18],0x0
004200c3  PUSH                   PUSH EBP
004200c4  MOV                    MOV ECX,ESI
004200c6  MOV                    MOV dword ptr [ESI + 0x1c],0x3ff00000
004200cd  MOV                    MOV dword ptr [ESI + 0x1b4],EDI
004200d3  CALL                   CALL 0x00428660
004200d8  MOV                    MOV ECX,ESI
004200da  CALL                   CALL 0x004286f0
004200df  PUSH                   PUSH EBX
004200e0  PUSH                   PUSH 0x27
004200e2  CALL                   CALL 0x0042f9b0
004200e7  ADD                    ADD ESP,0x8
004200ea  POP                    POP EDI
004200eb  POP                    POP ESI
004200ec  POP                    POP EBP
004200ed  XOR                    XOR EAX,EAX
004200ef  POP                    POP EBX
004200f0  RET                    RET
00420100  PUSH                   PUSH ECX
00420101  MOV                    MOV EAX,dword ptr [ESP + 0x8]
00420105  TEST                   TEST EAX,EAX
00420107  MOV                    MOV dword ptr [ESP],0x1
0042010f  JZ                     JZ 0x00420119
00420111  MOV                    MOV dword ptr [ESP],0x2
00420119  PUSH                   PUSH EBX
0042011a  MOV                    MOV EBX,dword ptr [ESP + 0x10]
0042011e  PUSH                   PUSH ESI
0042011f  PUSH                   PUSH EDI
00420120  PUSH                   PUSH EBX
00420121  MOV                    MOV ECX,0x4e48b8
00420126  CALL                   CALL 0x0041f040
0042012b  MOV                    MOV EDI,dword ptr [ESP + 0x1c]
0042012f  MOV                    MOV EAX,dword ptr [EDI + 0xc]
00420132  MOV                    MOV ESI,dword ptr [EAX + 0x78]
00420135  MOV                    MOV ECX,dword ptr [ESI + 0xc]
00420138  PUSH                   PUSH 0x0
0042013a  PUSH                   PUSH ECX
0042013b  MOV                    MOV ECX,dword ptr [0x004fe7ac]
00420141  PUSH                   PUSH 0x3fa
00420146  MOV                    MOV dword ptr [ESP + 0x24],ESI
0042014a  CALL                   CALL 0x0043cb00
0042014f  MOV                    MOV EAX,[0x004f2a10]
00420154  TEST                   TEST EAX,EAX
00420156  MOV                    MOV dword ptr [ESP + 0x14],0x0
0042015e  JLE                    JLE 0x0042020d
00420164  PUSH                   PUSH EBP
00420165  MOV                    MOV ESI,0x4f1b10
0042016a  MOV                    MOV ECX,ESI
0042016c  CALL                   CALL 0x004364a0
00420171  TEST                   TEST EAX,EAX
00420173  JZ                     JZ 0x004201eb
00420175  PUSH                   PUSH 0x1
00420177  MOV                    MOV ECX,ESI
00420179  CALL                   CALL 0x00435fe0
0042017e  TEST                   TEST EAX,EAX
00420180  JNZ                    JNZ 0x004201eb
00420182  MOV                    MOV ECX,EDI
00420184  CALL                   CALL 0x00435620
00420189  MOV                    MOV ECX,ESI
0042018b  MOV                    MOV EBP,EAX
0042018d  CALL                   CALL 0x00435620
00420192  CMP                    CMP EAX,EBP
00420194  JZ                     JZ 0x004201eb
00420196  PUSH                   PUSH 0x4fdb20
0042019b  PUSH                   PUSH 0x3f6
004201a0  MOV                    MOV ECX,0x5090b0
004201a5  MOV                    MOV dword ptr [0x004fdb20],ESI
004201ab  MOV                    MOV dword ptr [0x004fdb24],EDI
004201b1  CALL                   CALL 0x0042ab30
004201b6  MOV                    MOV EDX,dword ptr [EDI + 0x38]
004201b9  MOV                    MOV ECX,dword ptr [0x004fe7ac]
004201bf  SHL                    SHL EDX,0x8
004201c2  PUSH                   PUSH ESI
004201c3  OR                     OR EDX,EBX
004201c5  PUSH                   PUSH EDX
004201c6  PUSH                   PUSH 0x404
004201cb  CALL                   CALL 0x0043c5e0
004201d0  MOV                    MOV ECX,ESI
004201d2  CALL                   CALL 0x00435510
004201d7  MOV                    MOV EAX,[0x00508e80]
004201dc  IMUL                   IMUL EAX,dword ptr [ESP + 0x10]
004201e1  PUSH                   PUSH EAX
004201e2  PUSH                   PUSH 0x2
004201e4  MOV                    MOV ECX,ESI
004201e6  CALL                   CALL 0x00435f80
004201eb  MOV                    MOV EAX,dword ptr [ESP + 0x18]
004201ef  MOV                    MOV ECX,dword ptr [0x004f2a10]
004201f5  INC                    INC EAX
004201f6  ADD                    ADD ESI,0x1e0
004201fc  CMP                    CMP EAX,ECX
004201fe  MOV                    MOV dword ptr [ESP + 0x18],EAX
00420202  JL                     JL 0x0042016a
00420208  MOV                    MOV ESI,dword ptr [ESP + 0x1c]
0042020c  POP                    POP EBP
0042020d  PUSH                   PUSH ESI
0042020e  PUSH                   PUSH 0x28
00420210  CALL                   CALL 0x0042f9b0
00420215  ADD                    ADD ESP,0x8
00420218  POP                    POP EDI
00420219  POP                    POP ESI
0042021a  XOR                    XOR EAX,EAX
0042021c  POP                    POP EBX
0042021d  POP                    POP ECX
0042021e  RET                    RET
00420220  PUSH                   PUSH ECX
00420221  MOV                    MOV EAX,dword ptr [ESP + 0x8]
00420225  TEST                   TEST EAX,EAX
00420227  MOV                    MOV dword ptr [ESP],0x1
0042022f  JZ                     JZ 0x00420239
00420231  MOV                    MOV dword ptr [ESP],0x2
00420239  MOV                    MOV EAX,dword ptr [ESP + 0x14]
0042023d  PUSH                   PUSH ESI
0042023e  PUSH                   PUSH EAX
0042023f  MOV                    MOV ECX,0x4e3b48
00420244  CALL                   CALL 0x00441000
00420249  FILD                   FILD dword ptr [ESP + 0x4]
0042024d  PUSH                   PUSH 0x0
0042024f  PUSH                   PUSH ECX
00420250  FMUL                   FMUL float ptr [0x00508e84]
00420256  MOV                    MOV ESI,EAX
00420258  MOV                    MOV ECX,0x4e3b48
0042025d  FADD                   FADD float ptr [0x0049546c]
00420263  FSTP                   FSTP float ptr [ESP]
00420266  PUSH                   PUSH ESI
00420267  CALL                   CALL 0x00441790
0042026c  MOV                    MOV ECX,dword ptr [ESP + 0x14]
00420270  PUSH                   PUSH 0x4fdb20
00420275  MOV                    MOV dword ptr [0x004fdb20],ECX
0042027b  PUSH                   PUSH 0x3f7
00420280  MOV                    MOV ECX,0x5090b0
00420285  MOV                    MOV dword ptr [0x004fdb2c],ESI
0042028b  CALL                   CALL 0x0042ab30
00420290  XOR                    XOR EAX,EAX
00420292  POP                    POP ESI
00420293  POP                    POP ECX
00420294  RET                    RET
004202a0  PUSH                   PUSH ECX
004202a1  MOV                    MOV EAX,dword ptr [ESP + 0x8]
004202a5  TEST                   TEST EAX,EAX
004202a7  MOV                    MOV dword ptr [ESP],0x1
004202af  JZ                     JZ 0x004202b9
004202b1  MOV                    MOV dword ptr [ESP],0x2
004202b9  MOV                    MOV EAX,dword ptr [ESP + 0x14]
004202bd  PUSH                   PUSH ESI
004202be  PUSH                   PUSH EDI
004202bf  PUSH                   PUSH EAX
004202c0  MOV                    MOV ECX,0x4e3b48
004202c5  CALL                   CALL 0x00441000
004202ca  FILD                   FILD dword ptr [ESP + 0x8]
004202ce  PUSH                   PUSH 0x0
004202d0  PUSH                   PUSH ECX
004202d1  FMUL                   FMUL float ptr [0x00508e88]
004202d7  MOV                    MOV ESI,EAX
004202d9  MOV                    MOV ECX,0x4e3b48
004202de  FSUBR                  FSUBR float ptr [0x0049546c]
004202e4  FSTP                   FSTP float ptr [ESP]
004202e7  PUSH                   PUSH ESI
004202e8  CALL                   CALL 0x00441790
004202ed  MOV                    MOV EDI,dword ptr [ESP + 0x18]
004202f1  PUSH                   PUSH 0x4fdb20
004202f6  PUSH                   PUSH 0x3f8
004202fb  MOV                    MOV ECX,0x5090b0
00420300  MOV                    MOV dword ptr [0x004fdb20],EDI
00420306  MOV                    MOV dword ptr [0x004fdb2c],ESI
0042030c  CALL                   CALL 0x0042ab30
00420311  MOV                    MOV EAX,dword ptr [ESI + 0x40]
00420314  TEST                   TEST EAX,EAX
00420316  JZ                     JZ 0x00420344
00420318  MOV                    MOV EAX,dword ptr [ESI + 0x48]
0042031b  TEST                   TEST EAX,EAX
0042031d  JNZ                    JNZ 0x00420344
0042031f  MOV                    MOV EDI,dword ptr [EDI + 0x38]
00420322  MOV                    MOV ECX,ESI
00420324  CALL                   CALL 0x00440170
00420329  MOV                    MOV EDX,dword ptr [ESP + 0x14]
0042032d  MOV                    MOV ECX,dword ptr [0x004fe7ac]
00420333  SHL                    SHL EDI,0x8
00420336  PUSH                   PUSH EAX
00420337  OR                     OR EDI,EDX
00420339  PUSH                   PUSH EDI
0042033a  PUSH                   PUSH 0x404
0042033f  CALL                   CALL 0x0043c5e0
00420344  POP                    POP EDI
00420345  XOR                    XOR EAX,EAX
00420347  POP                    POP ESI
00420348  POP                    POP ECX
00420349  RET                    RET
00420350  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00420354  TEST                   TEST EAX,EAX
00420356  PUSH                   PUSH EBX
00420357  PUSH                   PUSH ESI
00420358  PUSH                   PUSH EDI
00420359  MOV                    MOV EBX,0x1
0042035e  JZ                     JZ 0x00420365
00420360  MOV                    MOV EBX,0x2
00420365  MOV                    MOV EDI,dword ptr [ESP + 0x18]
00420369  MOV                    MOV EAX,dword ptr [EDI + 0xc]
0042036c  MOV                    MOV ESI,dword ptr [EAX + 0x78]
0042036f  MOV                    MOV EAX,[0x00508e90]
00420374  MOV                    MOV ECX,dword ptr [ESI + 0x3c]
00420377  IMUL                   IMUL EAX,EBX
0042037a  LEA                    LEA EDX,[EAX + EAX*0x2]
0042037d  MOV                    MOV EAX,dword ptr [ECX + 0x28]
00420380  SHL                    SHL EDX,0x3
00420383  ADD                    ADD EAX,EDX
00420385  MOV                    MOV dword ptr [ECX + 0x28],EAX
00420388  MOV                    MOV EAX,dword ptr [ESI + 0xc]
0042038b  MOV                    MOV ECX,dword ptr [0x004fe7ac]
00420391  PUSH                   PUSH 0x1
00420393  PUSH                   PUSH EAX
00420394  PUSH                   PUSH 0xce
00420399  CALL                   CALL 0x0043cb00
0042039e  MOV                    MOV EDX,dword ptr [0x00508e90]
004203a4  MOV                    MOV ECX,dword ptr [ESI + 0x3c]
004203a7  IMUL                   IMUL EDX,EBX
004203aa  PUSH                   PUSH 0xc25
004203af  MOV                    MOV dword ptr [0x004fdb3c],ECX
004203b5  MOV                    MOV dword ptr [0x004fdb24],EDI
004203bb  MOV                    MOV dword ptr [0x004fdb34],EDX
004203c1  CALL                   CALL 0x00431100
004203c6  PUSH                   PUSH ESI
004203c7  PUSH                   PUSH 0x2b
004203c9  CALL                   CALL 0x0042f9b0
004203ce  ADD                    ADD ESP,0xc
004203d1  MOV                    MOV dword ptr [0x004fdb20],EDI
004203d7  MOV                    MOV EAX,dword ptr [ESI + 0x3c]
004203da  PUSH                   PUSH 0x4fdb20
004203df  PUSH                   PUSH 0x3f9
004203e4  MOV                    MOV ECX,0x5090b0
004203e9  MOV                    MOV [0x004fdb3c],EAX
004203ee  CALL                   CALL 0x0042ab30
004203f3  POP                    POP EDI
004203f4  POP                    POP ESI
004203f5  XOR                    XOR EAX,EAX
004203f7  POP                    POP EBX
004203f8  RET                    RET
00420400  MOV                    MOV EAX,dword ptr [ESP + 0x10]
00420404  PUSH                   PUSH EDI
00420405  PUSH                   PUSH EAX
00420406  MOV                    MOV ECX,0x4e48b8
0042040b  CALL                   CALL 0x0041f060
00420410  PUSH                   PUSH 0x1f
00420412  MOV                    MOV ECX,0x4e48b8
00420417  MOV                    MOV EDI,EAX
00420419  CALL                   CALL 0x0041ee80
0042041e  TEST                   TEST AX,AX
00420421  MOV                    MOV dword ptr [ESP + 0x14],EAX
00420425  JGE                    JGE 0x0042042e
00420427  MOV                    MOV EAX,0x1
0042042c  POP                    POP EDI
0042042d  RET                    RET
0042042e  MOV                    MOV ECX,dword ptr [EDI + 0x4]
00420431  PUSH                   PUSH ESI
00420432  MOV                    MOV ESI,dword ptr [ESP + 0x14]
00420436  PUSH                   PUSH ESI
00420437  MOVSX                  MOVSX EDX,AX
0042043a  PUSH                   PUSH ECX
0042043b  PUSH                   PUSH EDX
0042043c  MOV                    MOV ECX,0x4e48b8
00420441  CALL                   CALL 0x0041f110
00420446  PUSH                   PUSH 0x0
00420448  LEA                    LEA EAX,[ESP + 0x1c]
0042044c  PUSH                   PUSH EAX
0042044d  PUSH                   PUSH 0x1
0042044f  MOV                    MOV ECX,ESI
00420451  CALL                   CALL 0x00434ae0
00420456  POP                    POP ESI
00420457  XOR                    XOR EAX,EAX
00420459  POP                    POP EDI
0042045a  RET                    RET
00420460  MOV                    MOV EAX,dword ptr [ESP + 0x10]
00420464  MOV                    MOV dword ptr [ESP + 0x10],EAX
00420468  PUSH                   PUSH ESI
00420469  MOV                    MOV ESI,dword ptr [ESP + 0x10]
0042046d  MOVSX                  MOVSX EAX,AX
00420470  PUSH                   PUSH EAX
00420471  MOV                    MOV ECX,ESI
00420473  CALL                   CALL 0x00434f40
00420478  CMP                    CMP EAX,-0x1
0042047b  JNZ                    JNZ 0x00420484
0042047d  MOV                    MOV EAX,0x1
00420482  POP                    POP ESI
00420483  RET                    RET
00420484  MOVSX                  MOVSX ECX,word ptr [ESP + 0x14]
00420489  PUSH                   PUSH EBX
0042048a  PUSH                   PUSH EDI
0042048b  PUSH                   PUSH ECX
0042048c  MOV                    MOV ECX,0x4e48b8
00420491  CALL                   CALL 0x0041f060
00420496  MOV                    MOV EDI,dword ptr [EAX + 0x4]
00420499  PUSH                   PUSH 0x0
0042049b  LEA                    LEA EDX,[ESP + 0x20]
0042049f  PUSH                   PUSH EDX
004204a0  PUSH                   PUSH 0x1
004204a2  MOV                    MOV ECX,ESI
004204a4  CALL                   CALL 0x00434c40
004204a9  MOVSX                  MOVSX EAX,word ptr [ESP + 0x1c]
004204ae  PUSH                   PUSH EAX
004204af  MOV                    MOV ECX,0x4e48b8
004204b4  CALL                   CALL 0x0041f060
004204b9  MOV                    MOV EBX,dword ptr [EAX + 0x4]
004204bc  PUSH                   PUSH EDI
004204bd  MOV                    MOV ECX,0x4e48b8
004204c2  CALL                   CALL 0x0041ee80
004204c7  TEST                   TEST AX,AX
004204ca  MOV                    MOV dword ptr [ESP + 0x1c],EAX
004204ce  JGE                    JGE 0x004204f3
004204d0  PUSH                   PUSH EBX
004204d1  MOV                    MOV ECX,0x4e48b8
004204d6  CALL                   CALL 0x0041ee80
004204db  PUSH                   PUSH ESI
004204dc  MOVSX                  MOVSX ECX,AX


// ===== 421720 → 不是已识别函数（可能只被函数指针引用）→ 改为线性反汇编

00421720  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421724  MOV                    MOV EAX,dword ptr [EAX + 0xc]
00421727  MOV                    MOV EDX,dword ptr [EAX + 0x74]
0042172a  MOV                    MOV EAX,dword ptr [EAX + 0x78]
0042172d  XOR                    XOR ECX,ECX
0042172f  TEST                   TEST EDX,EDX
00421731  SETZ                   SETZ CL
00421734  PUSH                   PUSH 0x1
00421736  PUSH                   PUSH ECX
00421737  MOV                    MOV ECX,EAX
00421739  CALL                   CALL 0x0042bb70
0042173e  CMP                    CMP dword ptr [EAX + 0x34],-0x1
00421742  JZ                     JZ 0x00421747
00421744  XOR                    XOR EAX,EAX
00421746  RET                    RET
00421747  MOV                    MOV ECX,EAX
00421749  CALL                   CALL 0x0042bf50
0042174e  NEG                    NEG EAX
00421750  SBB                    SBB EAX,EAX
00421752  INC                    INC EAX
00421753  RET                    RET
00421760  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421764  MOV                    MOV EAX,dword ptr [EAX + 0xc]
00421767  MOV                    MOV EDX,dword ptr [EAX + 0x74]
0042176a  XOR                    XOR ECX,ECX
0042176c  TEST                   TEST EDX,EDX
0042176e  PUSH                   PUSH EBX
0042176f  SETZ                   SETZ CL
00421772  PUSH                   PUSH EBP
00421773  PUSH                   PUSH ESI
00421774  PUSH                   PUSH EDI
00421775  MOV                    MOV EDI,dword ptr [EAX + 0x78]
00421778  XOR                    XOR EBX,EBX
0042177a  MOV                    MOV EBP,ECX
0042177c  PUSH                   PUSH 0x1
0042177e  PUSH                   PUSH EBP
0042177f  MOV                    MOV ECX,EDI
00421781  CALL                   CALL 0x0042bb70
00421786  MOV                    MOV EDI,EAX
00421788  CMP                    CMP dword ptr [EDI + 0x34],-0x1
0042178c  JNZ                    JNZ 0x004217d3
0042178e  MOV                    MOV ECX,EDI
00421790  CALL                   CALL 0x0042bf50
00421795  TEST                   TEST EAX,EAX
00421797  JNZ                    JNZ 0x004217d3
00421799  MOV                    MOV ECX,EDI
0042179b  CALL                   CALL 0x0042bb50
004217a0  MOV                    MOV ESI,EAX
004217a2  TEST                   TEST ESI,ESI
004217a4  JZ                     JZ 0x004217d3
004217a6  MOV                    MOV EAX,dword ptr [ESI + 0x30]
004217a9  TEST                   TEST EAX,EAX
004217ab  JZ                     JZ 0x004217d3
004217ad  MOV                    MOV ECX,dword ptr [ESP + 0x14]
004217b1  CALL                   CALL 0x00435620
004217b6  CMP                    CMP dword ptr [ESI + 0x34],EAX
004217b9  JNZ                    JNZ 0x004217d3
004217bb  MOV                    MOV ESI,dword ptr [ESI + 0x30]
004217be  CMP                    CMP dword ptr [ESI + 0x34],0x3
004217c2  JZ                     JZ 0x004217e0
004217c4  PUSH                   PUSH ESI
004217c5  MOV                    MOV ECX,0x4ece18
004217ca  CALL                   CALL 0x0041ce40
004217cf  TEST                   TEST EAX,EAX
004217d1  JZ                     JZ 0x004217e0
004217d3  INC                    INC EBX
004217d4  CMP                    CMP EBX,0x5
004217d7  JLE                    JLE 0x0042177c
004217d9  POP                    POP EDI
004217da  POP                    POP ESI
004217db  POP                    POP EBP
004217dc  XOR                    XOR EAX,EAX
004217de  POP                    POP EBX
004217df  RET                    RET
004217e0  MOV                    MOV EDX,dword ptr [EDI + 0xc]
004217e3  MOV                    MOV EAX,dword ptr [ESP + 0x18]
004217e7  POP                    POP EDI
004217e8  POP                    POP ESI
004217e9  POP                    POP EBP
004217ea  MOV                    MOV dword ptr [EAX],EDX
004217ec  MOV                    MOV EAX,0x1
004217f1  POP                    POP EBX
004217f2  RET                    RET
00421800  MOV                    MOV ECX,dword ptr [ESP + 0x4]
00421804  CALL                   CALL 0x00435620
00421809  MOV                    MOV EDX,dword ptr [EAX + 0x4c]
0042180c  XOR                    XOR ECX,ECX
0042180e  CMP                    CMP EDX,0x249f0
00421814  SETL                   SETL CL
00421817  MOV                    MOV EAX,ECX
00421819  RET                    RET
00421820  SUB                    SUB ESP,0x28
00421823  PUSH                   PUSH ESI
00421824  MOV                    MOV ESI,dword ptr [ESP + 0x30]
00421828  PUSH                   PUSH EDI
00421829  MOV                    MOV ECX,ESI
0042182b  CALL                   CALL 0x00436080
00421830  MOV                    MOV EDI,EAX
00421832  MOV                    MOV EAX,dword ptr [ESI + 0xc]
00421835  MOV                    MOV EAX,dword ptr [EAX + 0x78]
00421838  PUSH                   PUSH EAX
00421839  PUSH                   PUSH 0x40e00000
0042183e  PUSH                   PUSH 0x0
00421840  LEA                    LEA ECX,[ESP + 0x14]
00421844  PUSH                   PUSH ECX
00421845  MOV                    MOV ECX,0x4f1b08
0042184a  CALL                   CALL 0x0043a6a0
0042184f  XOR                    XOR ECX,ECX
00421851  TEST                   TEST EAX,EAX
00421853  JLE                    JLE 0x00421865
00421855  LEA                    LEA EDX,[ESP + 0x8]
00421859  CMP                    CMP dword ptr [EDX],EDI
0042185b  JZ                     JZ 0x0042186d
0042185d  INC                    INC ECX
0042185e  ADD                    ADD EDX,0x4
00421861  CMP                    CMP ECX,EAX
00421863  JL                     JL 0x00421859
00421865  POP                    POP EDI
00421866  XOR                    XOR EAX,EAX
00421868  POP                    POP ESI
00421869  ADD                    ADD ESP,0x28
0042186c  RET                    RET
0042186d  POP                    POP EDI
0042186e  MOV                    MOV EAX,0x1
00421873  POP                    POP ESI
00421874  ADD                    ADD ESP,0x28
00421877  RET                    RET
00421880  SUB                    SUB ESP,0x10
00421883  MOV                    MOV EAX,dword ptr [ESP + 0x14]
00421887  PUSH                   PUSH EBX
00421888  PUSH                   PUSH EBP
00421889  PUSH                   PUSH ESI
0042188a  PUSH                   PUSH EDI
0042188b  PUSH                   PUSH EAX
0042188c  CALL                   CALL 0x00421980
00421891  MOV                    MOV ESI,EAX
00421893  XOR                    XOR EBP,EBP
00421895  ADD                    ADD ESP,0x4
00421898  CMP                    CMP ESI,EBP
0042189a  MOV                    MOV dword ptr [ESP + 0x14],ESI
0042189e  JNZ                    JNZ 0x004218aa
004218a0  POP                    POP EDI
004218a1  POP                    POP ESI
004218a2  POP                    POP EBP
004218a3  XOR                    XOR EAX,EAX
004218a5  POP                    POP EBX
004218a6  ADD                    ADD ESP,0x10
004218a9  RET                    RET
004218aa  CMP                    CMP dword ptr [0x004f2a30],EBP
004218b0  JNZ                    JNZ 0x00421964
004218b6  MOV                    MOV EDX,dword ptr [ESI + 0xc]
004218b9  MOV                    MOV EAX,dword ptr [EDX + 0x78]
004218bc  MOV                    MOV dword ptr [ESP + 0x1c],EAX
004218c0  MOV                    MOV dword ptr [ESP + 0x18],EAX
004218c4  MOV                    MOV EAX,[0x00508e78]
004218c9  CDQ                    CDQ
004218ca  SUB                    SUB EAX,EDX
004218cc  SAR                    SAR EAX,0x1
004218ce  TEST                   TEST EAX,EAX
004218d0  MOV                    MOV dword ptr [ESP + 0x10],EBP
004218d4  JLE                    JLE 0x00421949
004218d6  XOR                    XOR EBX,EBX
004218d8  LEA                    LEA EDI,[ESP + 0x18]
004218dc  MOV                    MOV ECX,dword ptr [EDI]
004218de  PUSH                   PUSH 0x1
004218e0  PUSH                   PUSH EBX
004218e1  CALL                   CALL 0x0042bb70
004218e6  MOV                    MOV ECX,EAX
004218e8  MOV                    MOV dword ptr [EDI],EAX
004218ea  CALL                   CALL 0x0042bb50
004218ef  MOV                    MOV ESI,EAX
004218f1  TEST                   TEST ESI,ESI
004218f3  JZ                     JZ 0x00421921
004218f5  MOV                    MOV EAX,dword ptr [ESI + 0x30]
004218f8  TEST                   TEST EAX,EAX
004218fa  JZ                     JZ 0x0042190a
004218fc  MOV                    MOV ECX,dword ptr [ESP + 0x24]
00421900  CALL                   CALL 0x00435620
00421905  CMP                    CMP dword ptr [ESI + 0x34],EAX
00421908  JZ                     JZ 0x0042195a
0042190a  MOV                    MOV EAX,dword ptr [ESI + 0x30]
0042190d  PUSH                   PUSH EAX
0042190e  MOV                    MOV ECX,0x4ece18
00421913  CALL                   CALL 0x0041ce40
00421918  TEST                   TEST EAX,EAX
0042191a  JNZ                    JNZ 0x00421921
0042191c  MOV                    MOV EBP,0x1
00421921  INC                    INC EBX
00421922  ADD                    ADD EDI,0x4
00421925  CMP                    CMP EBX,0x2
00421928  JL                     JL 0x004218dc
0042192a  MOV                    MOV EAX,[0x00508e78]
0042192f  MOV                    MOV ECX,dword ptr [ESP + 0x10]
00421933  CDQ                    CDQ
00421934  SUB                    SUB EAX,EDX
00421936  INC                    INC ECX
00421937  SAR                    SAR EAX,0x1
00421939  CMP                    CMP ECX,EAX
0042193b  MOV                    MOV dword ptr [ESP + 0x10],ECX
0042193f  JL                     JL 0x004218d6
00421941  TEST                   TEST EBP,EBP
00421943  MOV                    MOV ESI,dword ptr [ESP + 0x14]
00421947  JNZ                    JNZ 0x00421964
00421949  PUSH                   PUSH 0x64
0042194b  PUSH                   PUSH 0x0
0042194d  CALL                   CALL 0x00405130
00421952  ADD                    ADD ESP,0x8
00421955  CMP                    CMP EAX,0x32
00421958  JLE                    JLE 0x00421964
0042195a  POP                    POP EDI
0042195b  POP                    POP ESI
0042195c  POP                    POP EBP
0042195d  XOR                    XOR EAX,EAX
0042195f  POP                    POP EBX
00421960  ADD                    ADD ESP,0x10
00421963  RET                    RET
00421964  MOV                    MOV ECX,dword ptr [ESI + 0xc]
00421967  MOV                    MOV EDX,dword ptr [ECX + 0x78]
0042196a  MOV                    MOV EAX,dword ptr [EDX + 0xc]
0042196d  MOV                    MOV ECX,dword ptr [ESP + 0x28]
00421971  POP                    POP EDI
00421972  POP                    POP ESI
00421973  POP                    POP EBP
00421974  MOV                    MOV dword ptr [ECX],EAX
00421976  MOV                    MOV EAX,0x1
0042197b  POP                    POP EBX
0042197c  ADD                    ADD ESP,0x10
0042197f  RET                    RET
00421980  SUB                    SUB ESP,0x30
00421983  PUSH                   PUSH EBX
00421984  MOV                    MOV EBX,dword ptr [ESP + 0x38]
00421988  MOV                    MOV ECX,dword ptr [EBX + 0xc]
0042198b  PUSH                   PUSH ESI
0042198c  PUSH                   PUSH EDI
0042198d  LEA                    LEA EAX,[ESP + 0xc]
00421991  PUSH                   PUSH EAX
00421992  PUSH                   PUSH 0x0
00421994  MOV                    MOV dword ptr [ESP + 0x14],0x0
0042199c  MOV                    MOV dword ptr [ESP + 0x18],0x0
004219a4  MOV                    MOV dword ptr [ESP + 0x1c],0x0
004219ac  MOV                    MOV dword ptr [ESP + 0x20],0x0
004219b4  MOV                    MOV dword ptr [ESP + 0x24],0x0
004219bc  MOV                    MOV dword ptr [ESP + 0x28],0x0
004219c4  MOV                    MOV dword ptr [ESP + 0x2c],0x0
004219cc  MOV                    MOV dword ptr [ESP + 0x30],0x0
004219d4  MOV                    MOV dword ptr [ESP + 0x34],0x0
004219dc  MOV                    MOV ECX,dword ptr [ECX + 0x78]
004219df  PUSH                   PUSH 0x0
004219e1  CALL                   CALL 0x0042bd30
004219e6  MOV                    MOV EAX,[0x004f2a10]
004219eb  XOR                    XOR EDI,EDI
004219ed  TEST                   TEST EAX,EAX
004219ef  JLE                    JLE 0x00421aca
004219f5  MOV                    MOV ESI,0x4f1b10
004219fa  MOV                    MOV EDX,dword ptr [ESI + 0x1c0]
00421a00  CMP                    CMP EDX,dword ptr [EBX + 0x1c0]
00421a06  JZ                     JZ 0x00421ab6
00421a0c  MOV                    MOV EAX,dword ptr [ESI + 0xc]
00421a0f  MOV                    MOV ECX,dword ptr [EAX + 0x98]
00421a15  TEST                   TEST ECX,ECX
00421a17  JZ                     JZ 0x00421ab6
00421a1d  MOV                    MOV ECX,ESI
00421a1f  CALL                   CALL 0x004364a0
00421a24  TEST                   TEST EAX,EAX
00421a26  JZ                     JZ 0x00421ab6
00421a2c  PUSH                   PUSH 0x1
00421a2e  MOV                    MOV ECX,ESI
00421a30  CALL                   CALL 0x00435fe0
00421a35  TEST                   TEST EAX,EAX
00421a37  JNZ                    JNZ 0x00421ab6
00421a39  MOV                    MOV EDX,dword ptr [ESI + 0xc]
00421a3c  LEA                    LEA ECX,[ESP + 0x18]
00421a40  PUSH                   PUSH ECX
00421a41  MOV                    MOV ECX,dword ptr [EDX + 0x78]
00421a44  PUSH                   PUSH EAX
00421a45  PUSH                   PUSH EAX
00421a46  CALL                   CALL 0x0042bd30
00421a4b  FLD                    FLD float ptr [ESP + 0xc]
00421a4f  FSUB                   FSUB float ptr [ESP + 0x18]
00421a53  FLD                    FLD float ptr [ESP + 0x10]
00421a57  FSUB                   FSUB float ptr [ESP + 0x1c]
00421a5b  FSTP                   FSTP float ptr [ESP + 0x34]
00421a5f  FLD                    FLD float ptr [ESP + 0x14]
00421a63  MOV                    MOV EAX,dword ptr [ESP + 0x34]
00421a67  FSUB                   FSUB float ptr [ESP + 0x20]
00421a6b  MOV                    MOV dword ptr [ESP + 0x28],EAX
00421a6f  FSTP                   FSTP float ptr [ESP + 0x38]
00421a73  MOV                    MOV ECX,dword ptr [ESP + 0x38]
00421a77  MOV                    MOV dword ptr [ESP + 0x2c],ECX
00421a7b  FSTP                   FSTP float ptr [ESP + 0x24]
00421a7f  LEA                    LEA ECX,[ESP + 0x24]
00421a83  CALL                   CALL 0x00403e20
00421a88  FDIV                   FDIV float ptr [0x00495b50]
00421a8e  FCOM                   FCOM float ptr [0x00495474]
00421a94  FNSTSW                 FNSTSW AX
00421a96  TEST                   TEST AH,0x1
00421a99  JZ                     JZ 0x00421ab4
00421a9b  FILD                   FILD dword ptr [0x00508e78]
00421aa1  FMUL                   FMUL float ptr [0x00495490]
00421aa7  FXCH                   FXCH
00421aa9  FCOMPP                 FCOMPP
00421aab  FNSTSW                 FNSTSW AX
00421aad  TEST                   TEST AH,0x41
00421ab0  JZ                     JZ 0x00421ad3
00421ab2  JMP                    JMP 0x00421ab6
00421ab4  FSTP                   FSTP ST0
00421ab6  MOV                    MOV EAX,[0x004f2a10]
00421abb  INC                    INC EDI
00421abc  ADD                    ADD ESI,0x1e0
00421ac2  CMP                    CMP EDI,EAX
00421ac4  JL                     JL 0x004219fa
00421aca  POP                    POP EDI
00421acb  POP                    POP ESI
00421acc  XOR                    XOR EAX,EAX
00421ace  POP                    POP EBX
00421acf  ADD                    ADD ESP,0x30
00421ad2  RET                    RET
00421ad3  POP                    POP EDI
00421ad4  MOV                    MOV EAX,ESI
00421ad6  POP                    POP ESI
00421ad7  POP                    POP EBX
00421ad8  ADD                    ADD ESP,0x30
00421adb  RET                    RET
00421ae0  PUSH                   PUSH 0x3
00421ae2  PUSH                   PUSH 0x1
00421ae4  CALL                   CALL 0x00405130
00421ae9  ADD                    ADD ESP,0x8
00421aec  DEC                    DEC EAX
00421aed  NEG                    NEG EAX
00421aef  SBB                    SBB EAX,EAX
00421af1  INC                    INC EAX
00421af2  RET                    RET
00421b00  MOV                    MOV EAX,[0x004e3b74]
00421b05  TEST                   TEST EAX,EAX
00421b07  JZ                     JZ 0x00421b0c
00421b09  XOR                    XOR EAX,EAX
00421b0b  RET                    RET
00421b0c  PUSH                   PUSH ESI
00421b0d  MOV                    MOV ESI,dword ptr [ESP + 0x8]
00421b11  PUSH                   PUSH EDI
00421b12  MOV                    MOV ECX,ESI
00421b14  CALL                   CALL 0x00435620
00421b19  MOV                    MOV EDI,dword ptr [EAX + 0x44]
00421b1c  MOV                    MOV ECX,ESI
00421b1e  CALL                   CALL 0x00435620
00421b23  MOV                    MOV ECX,EAX
00421b25  CALL                   CALL 0x004406b0
00421b2a  MOV                    MOV ESI,dword ptr [EAX + 0x44]
00421b2d  PUSH                   PUSH 0x2
00421b2f  PUSH                   PUSH 0x1
00421b31  CALL                   CALL 0x00405130
00421b36  ADD                    ADD ESP,0x8
00421b39  CMP                    CMP EAX,0x1
00421b3c  JNZ                    JNZ 0x00421b4c
00421b3e  MOV                    MOV EAX,dword ptr [ESP + 0x10]
00421b42  MOV                    MOV dword ptr [EAX],EDI
00421b44  POP                    POP EDI
00421b45  MOV                    MOV EAX,0x1
00421b4a  POP                    POP ESI
00421b4b  RET                    RET
00421b4c  MOV                    MOV ECX,dword ptr [ESP + 0x10]
00421b50  POP                    POP EDI
00421b51  MOV                    MOV dword ptr [ECX],ESI
00421b53  MOV                    MOV EAX,0x1
00421b58  POP                    POP ESI
00421b59  RET                    RET
00421b60  MOV                    MOV EAX,[0x004e3b74]
00421b65  TEST                   TEST EAX,EAX
00421b67  PUSH                   PUSH EBX
00421b68  PUSH                   PUSH EBP
00421b69  JNZ                    JNZ 0x00421c82
00421b6f  MOV                    MOV ECX,dword ptr [ESP + 0xc]
00421b73  CALL                   CALL 0x00436080
00421b78  TEST                   TEST EAX,EAX
00421b7a  JZ                     JZ 0x00421c82
00421b80  MOV                    MOV ECX,dword ptr [EAX + 0x1c0]
00421b86  TEST                   TEST ECX,ECX
00421b88  JZ                     JZ 0x00421c82
00421b8e  PUSH                   PUSH ESI
00421b8f  PUSH                   PUSH EDI
00421b90  MOV                    MOV ECX,EAX
00421b92  CALL                   CALL 0x00435620
00421b97  MOV                    MOV ECX,EAX
00421b99  CALL                   CALL 0x004406b0
00421b9e  MOV                    MOV EBP,EAX
00421ba0  MOV                    MOV EAX,[0x004e3b50]
00421ba5  XOR                    XOR EDI,EDI
00421ba7  OR                     OR EBX,0xffffffff
00421baa  XOR                    XOR ESI,ESI
00421bac  TEST                   TEST EAX,EAX
00421bae  JLE                    JLE 0x00421bda
00421bb0  PUSH                   PUSH ESI
00421bb1  MOV                    MOV ECX,0x4e3b48
00421bb6  CALL                   CALL 0x00441000
00421bbb  MOV                    MOV ECX,dword ptr [EAX + 0x40]
00421bbe  TEST                   TEST ECX,ECX
00421bc0  JZ                     JZ 0x00421bd0
00421bc2  MOV                    MOV EAX,dword ptr [EAX + 0x2dc]
00421bc8  CMP                    CMP EDI,EAX
00421bca  JGE                    JGE 0x00421bd0


// ===== 41ff10 → 不是已识别函数（可能只被函数指针引用）→ 改为线性反汇编

0041ff10  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041ff14  TEST                   TEST EAX,EAX
0041ff16  PUSH                   PUSH ESI
0041ff17  PUSH                   PUSH EDI
0041ff18  MOV                    MOV EDI,0x1
0041ff1d  JZ                     JZ 0x0041ff24
0041ff1f  MOV                    MOV EDI,0x2
0041ff24  MOV                    MOV ESI,dword ptr [ESP + 0x14]
0041ff28  MOV                    MOV EAX,dword ptr [ESI + 0xc]
0041ff2b  MOV                    MOV EDX,dword ptr [EAX + 0x74]
0041ff2e  MOV                    MOV EAX,dword ptr [EAX + 0x78]
0041ff31  XOR                    XOR ECX,ECX
0041ff33  TEST                   TEST EDX,EDX
0041ff35  SETZ                   SETZ CL
0041ff38  PUSH                   PUSH 0x1
0041ff3a  PUSH                   PUSH ECX
0041ff3b  MOV                    MOV ECX,EAX
0041ff3d  CALL                   CALL 0x0042bb70
0041ff42  MOV                    MOV ECX,dword ptr [EAX + 0x34]
0041ff45  TEST                   TEST ECX,ECX
0041ff47  JL                     JL 0x0041ff51
0041ff49  POP                    POP EDI
0041ff4a  MOV                    MOV EAX,0x1
0041ff4f  POP                    POP ESI
0041ff50  RET                    RET
0041ff51  PUSH                   PUSH 0x9
0041ff53  MOV                    MOV ECX,EAX
0041ff55  CALL                   CALL 0x0042be00
0041ff5a  TEST                   TEST EAX,EAX
0041ff5c  JGE                    JGE 0x0041ff66
0041ff5e  POP                    POP EDI
0041ff5f  MOV                    MOV EAX,0x1
0041ff64  POP                    POP ESI
0041ff65  RET                    RET
0041ff66  PUSH                   PUSH EAX
0041ff67  MOV                    MOV ECX,0x4f2e68
0041ff6c  CALL                   CALL 0x00431ac0
0041ff71  MOV                    MOV dword ptr [EAX + 0x4],EDI
0041ff74  MOV                    MOV EDX,dword ptr [ESI + 0xc]
0041ff77  MOV                    MOV EAX,dword ptr [EDX + 0x78]
0041ff7a  PUSH                   PUSH EAX
0041ff7b  PUSH                   PUSH 0x23
0041ff7d  CALL                   CALL 0x0042f9b0
0041ff82  PUSH                   PUSH 0xc22
0041ff87  MOV                    MOV dword ptr [0x004fdb24],ESI
0041ff8d  CALL                   CALL 0x00431100
0041ff92  ADD                    ADD ESP,0xc
0041ff95  POP                    POP EDI
0041ff96  XOR                    XOR EAX,EAX
0041ff98  POP                    POP ESI
0041ff99  RET                    RET
0041ffa0  MOV                    MOV EAX,dword ptr [ESP + 0x10]
0041ffa4  MOV                    MOV EDX,dword ptr [0x004e3834]
0041ffaa  MOV                    MOV ECX,EAX
0041ffac  SHL                    SHL ECX,0x4
0041ffaf  ADD                    ADD ECX,EAX
0041ffb1  MOV                    MOV EAX,dword ptr [EDX + ECX*0x4 + 0x34]
0041ffb5  TEST                   TEST EAX,EAX
0041ffb7  LEA                    LEA ECX,[EDX + ECX*0x4]
0041ffba  JL                     JL 0x0041ffc2
0041ffbc  MOV                    MOV EAX,0x1
0041ffc1  RET                    RET
0041ffc2  PUSH                   PUSH 0x8
0041ffc4  CALL                   CALL 0x0042be00
0041ffc9  TEST                   TEST EAX,EAX
0041ffcb  JGE                    JGE 0x0041ffd3
0041ffcd  MOV                    MOV EAX,0x1
0041ffd2  RET                    RET
0041ffd3  MOV                    MOV EAX,dword ptr [ESP + 0xc]
0041ffd7  MOV                    MOV ECX,dword ptr [EAX + 0xc]
0041ffda  MOV                    MOV EDX,dword ptr [ECX + 0x78]
0041ffdd  PUSH                   PUSH EDX
0041ffde  PUSH                   PUSH 0x25
0041ffe0  CALL                   CALL 0x0042f9b0
0041ffe5  ADD                    ADD ESP,0x8
0041ffe8  XOR                    XOR EAX,EAX
0041ffea  RET                    RET
0041fff0  MOV                    MOV ECX,dword ptr [ESP + 0x4]
0041fff4  TEST                   TEST ECX,ECX
0041fff6  MOV                    MOV EAX,0x1
0041fffb  JZ                     JZ 0x00420002
0041fffd  MOV                    MOV EAX,0x2
00420002  MOV                    MOV ECX,dword ptr [0x00508e70]
00420008  IMUL                   IMUL ECX,EAX
0042000b  PUSH                   PUSH ECX
0042000c  MOV                    MOV ECX,dword ptr [ESP + 0x10]
00420010  PUSH                   PUSH 0x0
00420012  CALL                   CALL 0x00435f80
00420017  XOR                    XOR EAX,EAX
00420019  RET                    RET
00420020  MOV                    MOV ECX,dword ptr [ESP + 0x4]
00420024  TEST                   TEST ECX,ECX
00420026  MOV                    MOV EAX,0x1
0042002b  JZ                     JZ 0x00420032
0042002d  MOV                    MOV EAX,0x2
00420032  MOV                    MOV ECX,dword ptr [0x00508e74]
00420038  IMUL                   IMUL ECX,EAX
0042003b  PUSH                   PUSH ESI
0042003c  MOV                    MOV ESI,dword ptr [ESP + 0x10]
00420040  PUSH                   PUSH ECX
00420041  PUSH                   PUSH 0x1
00420043  MOV                    MOV ECX,ESI
00420045  CALL                   CALL 0x00435f80
0042004a  PUSH                   PUSH 0x4fdb20
0042004f  PUSH                   PUSH 0x3f5
00420054  MOV                    MOV ECX,0x5090b0
00420059  MOV                    MOV dword ptr [0x004fdb20],ESI
0042005f  CALL                   CALL 0x0042ab30
00420064  MOV                    MOV EDX,dword ptr [ESI + 0xc]
00420067  MOV                    MOV EAX,dword ptr [EDX + 0x78]
0042006a  PUSH                   PUSH EAX
0042006b  PUSH                   PUSH 0x26
0042006d  CALL                   CALL 0x0042f9b0
00420072  ADD                    ADD ESP,0x8
00420075  XOR                    XOR EAX,EAX
00420077  POP                    POP ESI
00420078  RET                    RET
00420080  MOV                    MOV EDX,dword ptr [0x004e3834]
00420086  PUSH                   PUSH EBX
00420087  PUSH                   PUSH EBP
00420088  PUSH                   PUSH ESI
00420089  PUSH                   PUSH EDI
0042008a  MOV                    MOV EDI,dword ptr [ESP + 0x1c]
0042008e  MOV                    MOV EAX,dword ptr [EDI + 0xc]
00420091  MOV                    MOV EBP,dword ptr [EAX + 0x78]
00420094  MOV                    MOV EAX,dword ptr [ESP + 0x20]
00420098  MOV                    MOV ECX,EAX
0042009a  PUSH                   PUSH 0x40000000
0042009f  SHL                    SHL ECX,0x4
004200a2  ADD                    ADD ECX,EAX
004200a4  PUSH                   PUSH 0x0
004200a6  PUSH                   PUSH 0x7
004200a8  LEA                    LEA EBX,[EDX + ECX*0x4]
004200ab  CALL                   CALL 0x00427d70
004200b0  ADD                    ADD ESP,0xc
004200b3  PUSH                   PUSH EDI
004200b4  MOV                    MOV ESI,EAX
004200b6  PUSH                   PUSH 0x3f800000
004200bb  PUSH                   PUSH EBX
004200bc  MOV                    MOV dword ptr [ESI + 0x18],0x0
004200c3  PUSH                   PUSH EBP
004200c4  MOV                    MOV ECX,ESI
004200c6  MOV                    MOV dword ptr [ESI + 0x1c],0x3ff00000
004200cd  MOV                    MOV dword ptr [ESI + 0x1b4],EDI
004200d3  CALL                   CALL 0x00428660
004200d8  MOV                    MOV ECX,ESI
004200da  CALL                   CALL 0x004286f0
004200df  PUSH                   PUSH EBX
004200e0  PUSH                   PUSH 0x27
004200e2  CALL                   CALL 0x0042f9b0
004200e7  ADD                    ADD ESP,0x8
004200ea  POP                    POP EDI
004200eb  POP                    POP ESI
004200ec  POP                    POP EBP
004200ed  XOR                    XOR EAX,EAX
004200ef  POP                    POP EBX
004200f0  RET                    RET
00420100  PUSH                   PUSH ECX
00420101  MOV                    MOV EAX,dword ptr [ESP + 0x8]
00420105  TEST                   TEST EAX,EAX
00420107  MOV                    MOV dword ptr [ESP],0x1
0042010f  JZ                     JZ 0x00420119
00420111  MOV                    MOV dword ptr [ESP],0x2
00420119  PUSH                   PUSH EBX
0042011a  MOV                    MOV EBX,dword ptr [ESP + 0x10]
0042011e  PUSH                   PUSH ESI
0042011f  PUSH                   PUSH EDI
00420120  PUSH                   PUSH EBX
00420121  MOV                    MOV ECX,0x4e48b8
00420126  CALL                   CALL 0x0041f040
0042012b  MOV                    MOV EDI,dword ptr [ESP + 0x1c]
0042012f  MOV                    MOV EAX,dword ptr [EDI + 0xc]
00420132  MOV                    MOV ESI,dword ptr [EAX + 0x78]
00420135  MOV                    MOV ECX,dword ptr [ESI + 0xc]
00420138  PUSH                   PUSH 0x0
0042013a  PUSH                   PUSH ECX
0042013b  MOV                    MOV ECX,dword ptr [0x004fe7ac]
00420141  PUSH                   PUSH 0x3fa
00420146  MOV                    MOV dword ptr [ESP + 0x24],ESI
0042014a  CALL                   CALL 0x0043cb00
0042014f  MOV                    MOV EAX,[0x004f2a10]
00420154  TEST                   TEST EAX,EAX
00420156  MOV                    MOV dword ptr [ESP + 0x14],0x0
0042015e  JLE                    JLE 0x0042020d
00420164  PUSH                   PUSH EBP
00420165  MOV                    MOV ESI,0x4f1b10
0042016a  MOV                    MOV ECX,ESI
0042016c  CALL                   CALL 0x004364a0
00420171  TEST                   TEST EAX,EAX
00420173  JZ                     JZ 0x004201eb
00420175  PUSH                   PUSH 0x1
00420177  MOV                    MOV ECX,ESI
00420179  CALL                   CALL 0x00435fe0
0042017e  TEST                   TEST EAX,EAX
00420180  JNZ                    JNZ 0x004201eb
00420182  MOV                    MOV ECX,EDI
00420184  CALL                   CALL 0x00435620
00420189  MOV                    MOV ECX,ESI
0042018b  MOV                    MOV EBP,EAX
0042018d  CALL                   CALL 0x00435620
00420192  CMP                    CMP EAX,EBP
00420194  JZ                     JZ 0x004201eb
00420196  PUSH                   PUSH 0x4fdb20
0042019b  PUSH                   PUSH 0x3f6
004201a0  MOV                    MOV ECX,0x5090b0
004201a5  MOV                    MOV dword ptr [0x004fdb20],ESI
004201ab  MOV                    MOV dword ptr [0x004fdb24],EDI
004201b1  CALL                   CALL 0x0042ab30
004201b6  MOV                    MOV EDX,dword ptr [EDI + 0x38]
004201b9  MOV                    MOV ECX,dword ptr [0x004fe7ac]
004201bf  SHL                    SHL EDX,0x8
004201c2  PUSH                   PUSH ESI
004201c3  OR                     OR EDX,EBX
004201c5  PUSH                   PUSH EDX
004201c6  PUSH                   PUSH 0x404
004201cb  CALL                   CALL 0x0043c5e0
004201d0  MOV                    MOV ECX,ESI
004201d2  CALL                   CALL 0x00435510
004201d7  MOV                    MOV EAX,[0x00508e80]
004201dc  IMUL                   IMUL EAX,dword ptr [ESP + 0x10]
004201e1  PUSH                   PUSH EAX
004201e2  PUSH                   PUSH 0x2
004201e4  MOV                    MOV ECX,ESI
004201e6  CALL                   CALL 0x00435f80
004201eb  MOV                    MOV EAX,dword ptr [ESP + 0x18]
004201ef  MOV                    MOV ECX,dword ptr [0x004f2a10]
004201f5  INC                    INC EAX
004201f6  ADD                    ADD ESI,0x1e0
004201fc  CMP                    CMP EAX,ECX
004201fe  MOV                    MOV dword ptr [ESP + 0x18],EAX
00420202  JL                     JL 0x0042016a
00420208  MOV                    MOV ESI,dword ptr [ESP + 0x1c]
0042020c  POP                    POP EBP
0042020d  PUSH                   PUSH ESI
0042020e  PUSH                   PUSH 0x28
00420210  CALL                   CALL 0x0042f9b0
00420215  ADD                    ADD ESP,0x8
00420218  POP                    POP EDI
00420219  POP                    POP ESI
0042021a  XOR                    XOR EAX,EAX
0042021c  POP                    POP EBX
0042021d  POP                    POP ECX
0042021e  RET                    RET
00420220  PUSH                   PUSH ECX
00420221  MOV                    MOV EAX,dword ptr [ESP + 0x8]
00420225  TEST                   TEST EAX,EAX
00420227  MOV                    MOV dword ptr [ESP],0x1
0042022f  JZ                     JZ 0x00420239
00420231  MOV                    MOV dword ptr [ESP],0x2
00420239  MOV                    MOV EAX,dword ptr [ESP + 0x14]
0042023d  PUSH                   PUSH ESI
0042023e  PUSH                   PUSH EAX
0042023f  MOV                    MOV ECX,0x4e3b48
00420244  CALL                   CALL 0x00441000
00420249  FILD                   FILD dword ptr [ESP + 0x4]
0042024d  PUSH                   PUSH 0x0
0042024f  PUSH                   PUSH ECX
00420250  FMUL                   FMUL float ptr [0x00508e84]
00420256  MOV                    MOV ESI,EAX
00420258  MOV                    MOV ECX,0x4e3b48
0042025d  FADD                   FADD float ptr [0x0049546c]
00420263  FSTP                   FSTP float ptr [ESP]
00420266  PUSH                   PUSH ESI
00420267  CALL                   CALL 0x00441790
0042026c  MOV                    MOV ECX,dword ptr [ESP + 0x14]
00420270  PUSH                   PUSH 0x4fdb20
00420275  MOV                    MOV dword ptr [0x004fdb20],ECX
0042027b  PUSH                   PUSH 0x3f7
00420280  MOV                    MOV ECX,0x5090b0
00420285  MOV                    MOV dword ptr [0x004fdb2c],ESI
0042028b  CALL                   CALL 0x0042ab30
00420290  XOR                    XOR EAX,EAX
00420292  POP                    POP ESI
00420293  POP                    POP ECX
00420294  RET                    RET
004202a0  PUSH                   PUSH ECX
004202a1  MOV                    MOV EAX,dword ptr [ESP + 0x8]
004202a5  TEST                   TEST EAX,EAX
004202a7  MOV                    MOV dword ptr [ESP],0x1
004202af  JZ                     JZ 0x004202b9
004202b1  MOV                    MOV dword ptr [ESP],0x2
004202b9  MOV                    MOV EAX,dword ptr [ESP + 0x14]
004202bd  PUSH                   PUSH ESI
004202be  PUSH                   PUSH EDI
004202bf  PUSH                   PUSH EAX
004202c0  MOV                    MOV ECX,0x4e3b48
004202c5  CALL                   CALL 0x00441000
004202ca  FILD                   FILD dword ptr [ESP + 0x8]
004202ce  PUSH                   PUSH 0x0
004202d0  PUSH                   PUSH ECX
004202d1  FMUL                   FMUL float ptr [0x00508e88]
004202d7  MOV                    MOV ESI,EAX
004202d9  MOV                    MOV ECX,0x4e3b48
004202de  FSUBR                  FSUBR float ptr [0x0049546c]
004202e4  FSTP                   FSTP float ptr [ESP]
004202e7  PUSH                   PUSH ESI
004202e8  CALL                   CALL 0x00441790
004202ed  MOV                    MOV EDI,dword ptr [ESP + 0x18]
004202f1  PUSH                   PUSH 0x4fdb20
004202f6  PUSH                   PUSH 0x3f8
004202fb  MOV                    MOV ECX,0x5090b0
00420300  MOV                    MOV dword ptr [0x004fdb20],EDI
00420306  MOV                    MOV dword ptr [0x004fdb2c],ESI
0042030c  CALL                   CALL 0x0042ab30
00420311  MOV                    MOV EAX,dword ptr [ESI + 0x40]
00420314  TEST                   TEST EAX,EAX
00420316  JZ                     JZ 0x00420344
00420318  MOV                    MOV EAX,dword ptr [ESI + 0x48]
0042031b  TEST                   TEST EAX,EAX
0042031d  JNZ                    JNZ 0x00420344
0042031f  MOV                    MOV EDI,dword ptr [EDI + 0x38]
00420322  MOV                    MOV ECX,ESI
00420324  CALL                   CALL 0x00440170
00420329  MOV                    MOV EDX,dword ptr [ESP + 0x14]
0042032d  MOV                    MOV ECX,dword ptr [0x004fe7ac]
00420333  SHL                    SHL EDI,0x8
00420336  PUSH                   PUSH EAX
00420337  OR                     OR EDI,EDX
00420339  PUSH                   PUSH EDI
0042033a  PUSH                   PUSH 0x404
0042033f  CALL                   CALL 0x0043c5e0
00420344  POP                    POP EDI
00420345  XOR                    XOR EAX,EAX
00420347  POP                    POP ESI
00420348  POP                    POP ECX
00420349  RET                    RET
00420350  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00420354  TEST                   TEST EAX,EAX
00420356  PUSH                   PUSH EBX
00420357  PUSH                   PUSH ESI
00420358  PUSH                   PUSH EDI
00420359  MOV                    MOV EBX,0x1
0042035e  JZ                     JZ 0x00420365
00420360  MOV                    MOV EBX,0x2
00420365  MOV                    MOV EDI,dword ptr [ESP + 0x18]
00420369  MOV                    MOV EAX,dword ptr [EDI + 0xc]
0042036c  MOV                    MOV ESI,dword ptr [EAX + 0x78]
0042036f  MOV                    MOV EAX,[0x00508e90]
00420374  MOV                    MOV ECX,dword ptr [ESI + 0x3c]
00420377  IMUL                   IMUL EAX,EBX
0042037a  LEA                    LEA EDX,[EAX + EAX*0x2]
0042037d  MOV                    MOV EAX,dword ptr [ECX + 0x28]
00420380  SHL                    SHL EDX,0x3
00420383  ADD                    ADD EAX,EDX
00420385  MOV                    MOV dword ptr [ECX + 0x28],EAX
00420388  MOV                    MOV EAX,dword ptr [ESI + 0xc]
0042038b  MOV                    MOV ECX,dword ptr [0x004fe7ac]
00420391  PUSH                   PUSH 0x1
00420393  PUSH                   PUSH EAX
00420394  PUSH                   PUSH 0xce
00420399  CALL                   CALL 0x0043cb00
0042039e  MOV                    MOV EDX,dword ptr [0x00508e90]
004203a4  MOV                    MOV ECX,dword ptr [ESI + 0x3c]
004203a7  IMUL                   IMUL EDX,EBX
004203aa  PUSH                   PUSH 0xc25
004203af  MOV                    MOV dword ptr [0x004fdb3c],ECX
004203b5  MOV                    MOV dword ptr [0x004fdb24],EDI
004203bb  MOV                    MOV dword ptr [0x004fdb34],EDX
004203c1  CALL                   CALL 0x00431100
004203c6  PUSH                   PUSH ESI
004203c7  PUSH                   PUSH 0x2b
004203c9  CALL                   CALL 0x0042f9b0
004203ce  ADD                    ADD ESP,0xc
004203d1  MOV                    MOV dword ptr [0x004fdb20],EDI
004203d7  MOV                    MOV EAX,dword ptr [ESI + 0x3c]
004203da  PUSH                   PUSH 0x4fdb20
004203df  PUSH                   PUSH 0x3f9
004203e4  MOV                    MOV ECX,0x5090b0
004203e9  MOV                    MOV [0x004fdb3c],EAX
004203ee  CALL                   CALL 0x0042ab30
004203f3  POP                    POP EDI
004203f4  POP                    POP ESI
004203f5  XOR                    XOR EAX,EAX
004203f7  POP                    POP EBX
004203f8  RET                    RET
00420400  MOV                    MOV EAX,dword ptr [ESP + 0x10]
00420404  PUSH                   PUSH EDI
00420405  PUSH                   PUSH EAX
00420406  MOV                    MOV ECX,0x4e48b8
0042040b  CALL                   CALL 0x0041f060
00420410  PUSH                   PUSH 0x1f
00420412  MOV                    MOV ECX,0x4e48b8
00420417  MOV                    MOV EDI,EAX
00420419  CALL                   CALL 0x0041ee80
0042041e  TEST                   TEST AX,AX
00420421  MOV                    MOV dword ptr [ESP + 0x14],EAX
00420425  JGE                    JGE 0x0042042e
00420427  MOV                    MOV EAX,0x1
0042042c  POP                    POP EDI
0042042d  RET                    RET
0042042e  MOV                    MOV ECX,dword ptr [EDI + 0x4]
00420431  PUSH                   PUSH ESI
00420432  MOV                    MOV ESI,dword ptr [ESP + 0x14]
00420436  PUSH                   PUSH ESI
00420437  MOVSX                  MOVSX EDX,AX
0042043a  PUSH                   PUSH ECX
0042043b  PUSH                   PUSH EDX
0042043c  MOV                    MOV ECX,0x4e48b8
00420441  CALL                   CALL 0x0041f110
00420446  PUSH                   PUSH 0x0


// ===== 47e4e0 → FUN_0047e4e0 @ 0047e4e0（就是入口）  大小 6 字节

undefined4 FUN_0047e4e0(void)

{
  return 1;
}



// ===== 41f1a0 → 不是已识别函数（可能只被函数指针引用）→ 改为线性反汇编

0041f1a0  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041f1a4  TEST                   TEST EAX,EAX
0041f1a6  PUSH                   PUSH EBX
0041f1a7  PUSH                   PUSH EBP
0041f1a8  PUSH                   PUSH ESI
0041f1a9  PUSH                   PUSH EDI
0041f1aa  MOV                    MOV EBP,0x1
0041f1af  JZ                     JZ 0x0041f1b6
0041f1b1  MOV                    MOV EBP,0x2
0041f1b6  MOV                    MOV EAX,[0x00508e48]
0041f1bb  MOV                    MOV ECX,dword ptr [0x00508e44]
0041f1c1  IMUL                   IMUL EAX,EBP
0041f1c4  IMUL                   IMUL ECX,EBP
0041f1c7  PUSH                   PUSH EAX
0041f1c8  PUSH                   PUSH ECX
0041f1c9  CALL                   CALL 0x00405130
0041f1ce  ADD                    ADD ESP,0x8
0041f1d1  PUSH                   PUSH 0x3
0041f1d3  MOV                    MOV ECX,0x4e3b28
0041f1d8  MOV                    MOV ESI,EAX
0041f1da  CALL                   CALL 0x0041a950
0041f1df  MOV                    MOV EDI,EAX
0041f1e1  IMUL                   IMUL EDI,ESI
0041f1e4  MOV                    MOV ESI,dword ptr [ESP + 0x1c]
0041f1e8  PUSH                   PUSH 0x0
0041f1ea  PUSH                   PUSH EDI
0041f1eb  MOV                    MOV ECX,ESI
0041f1ed  CALL                   CALL 0x00435620
0041f1f2  MOV                    MOV ECX,EAX
0041f1f4  CALL                   CALL 0x0043ffe0
0041f1f9  MOV                    MOV EBX,dword ptr [0x00508e4c]
0041f1ff  IMUL                   IMUL EBX,EBP
0041f202  PUSH                   PUSH EBX
0041f203  PUSH                   PUSH 0x9
0041f205  MOV                    MOV ECX,ESI
0041f207  CALL                   CALL 0x00435f80
0041f20c  MOV                    MOV EDX,dword ptr [ESI + 0x38]
0041f20f  MOV                    MOV ECX,dword ptr [0x004fe7ac]
0041f215  OR                     OR EDX,0xffffff80
0041f218  SHL                    SHL EDX,0x18
0041f21b  PUSH                   PUSH ESI
0041f21c  OR                     OR EDX,EDI
0041f21e  PUSH                   PUSH EDX
0041f21f  PUSH                   PUSH 0x3e8
0041f224  CALL                   CALL 0x0043c5e0
0041f229  MOV                    MOV EAX,dword ptr [ESI + 0xc]
0041f22c  MOV                    MOV ECX,dword ptr [EAX + 0x78]
0041f22f  PUSH                   PUSH ECX
0041f230  PUSH                   PUSH 0x16
0041f232  CALL                   CALL 0x0042f9b0
0041f237  ADD                    ADD ESP,0x8
0041f23a  PUSH                   PUSH 0x4fdb20
0041f23f  PUSH                   PUSH 0x3e8
0041f244  MOV                    MOV ECX,0x5090b0
0041f249  MOV                    MOV dword ptr [0x004fdb20],ESI
0041f24f  MOV                    MOV dword ptr [0x004fdb34],EBX
0041f255  CALL                   CALL 0x0042ab30
0041f25a  POP                    POP EDI
0041f25b  POP                    POP ESI
0041f25c  POP                    POP EBP
0041f25d  XOR                    XOR EAX,EAX
0041f25f  POP                    POP EBX
0041f260  RET                    RET
0041f270  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041f274  SUB                    SUB ESP,0x28
0041f277  TEST                   TEST EAX,EAX
0041f279  PUSH                   PUSH EBX
0041f27a  PUSH                   PUSH ESI
0041f27b  PUSH                   PUSH EDI
0041f27c  MOV                    MOV EBX,0x1
0041f281  JZ                     JZ 0x0041f288
0041f283  MOV                    MOV EBX,0x2
0041f288  MOV                    MOV EAX,[0x00508e50]
0041f28d  PUSH                   PUSH EAX
0041f28e  LEA                    LEA ECX,[ESP + 0x10]
0041f292  PUSH                   PUSH ECX
0041f293  PUSH                   PUSH -0x1
0041f295  MOV                    MOV ECX,0x4e48b8
0041f29a  CALL                   CALL 0x0041ed50
0041f29f  TEST                   TEST EAX,EAX
0041f2a1  MOV                    MOV EDI,dword ptr [ESP + 0x40]
0041f2a5  JZ                     JZ 0x0041f2b6
0041f2a7  PUSH                   PUSH 0x0
0041f2a9  LEA                    LEA EDX,[ESP + 0x10]
0041f2ad  PUSH                   PUSH EDX
0041f2ae  PUSH                   PUSH EAX
0041f2af  MOV                    MOV ECX,EDI
0041f2b1  CALL                   CALL 0x00434ae0
0041f2b6  MOV                    MOV ESI,dword ptr [0x00508e54]
0041f2bc  IMUL                   IMUL ESI,EBX
0041f2bf  PUSH                   PUSH ESI
0041f2c0  PUSH                   PUSH 0x7
0041f2c2  MOV                    MOV ECX,EDI
0041f2c4  CALL                   CALL 0x00435f80
0041f2c9  MOV                    MOV EAX,dword ptr [EDI + 0xc]
0041f2cc  MOV                    MOV ECX,dword ptr [EAX + 0x78]
0041f2cf  PUSH                   PUSH ECX
0041f2d0  PUSH                   PUSH 0x18
0041f2d2  CALL                   CALL 0x0042f9b0
0041f2d7  ADD                    ADD ESP,0x8
0041f2da  PUSH                   PUSH 0x4fdb20
0041f2df  PUSH                   PUSH 0x3e9
0041f2e4  MOV                    MOV ECX,0x5090b0
0041f2e9  MOV                    MOV dword ptr [0x004fdb20],EDI
0041f2ef  MOV                    MOV dword ptr [0x004fdb34],ESI
0041f2f5  CALL                   CALL 0x0042ab30
0041f2fa  POP                    POP EDI
0041f2fb  POP                    POP ESI
0041f2fc  XOR                    XOR EAX,EAX
0041f2fe  POP                    POP EBX
0041f2ff  ADD                    ADD ESP,0x28
0041f302  RET                    RET
0041f310  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041f314  TEST                   TEST EAX,EAX
0041f316  PUSH                   PUSH EBX
0041f317  PUSH                   PUSH ESI
0041f318  PUSH                   PUSH EDI
0041f319  MOV                    MOV EDI,0x1
0041f31e  JZ                     JZ 0x0041f325
0041f320  MOV                    MOV EDI,0x2
0041f325  MOV                    MOV EAX,[0x00508e5c]
0041f32a  MOV                    MOV ECX,dword ptr [0x00508e58]
0041f330  IMUL                   IMUL EAX,EDI
0041f333  IMUL                   IMUL ECX,EDI
0041f336  PUSH                   PUSH EAX
0041f337  PUSH                   PUSH ECX
0041f338  CALL                   CALL 0x00405130
0041f33d  ADD                    ADD ESP,0x8
0041f340  PUSH                   PUSH 0x3
0041f342  MOV                    MOV ECX,0x4e3b28
0041f347  MOV                    MOV ESI,EAX
0041f349  CALL                   CALL 0x0041a950
0041f34e  MOV                    MOV EBX,EAX
0041f350  MOV                    MOV EAX,dword ptr [ESP + 0x1c]
0041f354  IMUL                   IMUL EBX,ESI
0041f357  LEA                    LEA ESI,[EAX + EAX*0x2]
0041f35a  LEA                    LEA ESI,[ESI + ESI*0x4]
0041f35d  SHL                    SHL ESI,0x5
0041f360  ADD                    ADD ESI,0x4f1b10
0041f366  PUSH                   PUSH 0x1
0041f368  MOV                    MOV ECX,ESI
0041f36a  CALL                   CALL 0x00435fe0
0041f36f  TEST                   TEST EAX,EAX
0041f371  JNZ                    JNZ 0x0041f46f
0041f377  MOV                    MOV EAX,dword ptr [ESI + 0x1c0]
0041f37d  TEST                   TEST EAX,EAX
0041f37f  JZ                     JZ 0x0041f46f
0041f385  MOV                    MOV EDX,dword ptr [ESI + 0xc]
0041f388  MOV                    MOV EAX,dword ptr [EDX + 0x78]
0041f38b  MOV                    MOV ECX,dword ptr [EAX + 0xc]
0041f38e  PUSH                   PUSH EBP
0041f38f  PUSH                   PUSH 0x0
0041f391  PUSH                   PUSH ECX
0041f392  MOV                    MOV ECX,dword ptr [0x004fe7ac]
0041f398  PUSH                   PUSH 0x3fe
0041f39d  CALL                   CALL 0x0043cb00
0041f3a2  PUSH                   PUSH 0x0
0041f3a4  PUSH                   PUSH EBX
0041f3a5  MOV                    MOV ECX,ESI
0041f3a7  CALL                   CALL 0x00435620
0041f3ac  MOV                    MOV ECX,EAX
0041f3ae  CALL                   CALL 0x0043ff30
0041f3b3  MOV                    MOV EBP,dword ptr [0x00508e60]
0041f3b9  IMUL                   IMUL EBP,EDI
0041f3bc  PUSH                   PUSH EBP
0041f3bd  PUSH                   PUSH 0x6
0041f3bf  MOV                    MOV ECX,ESI
0041f3c1  CALL                   CALL 0x00435f80
0041f3c6  MOV                    MOV ECX,dword ptr [ESP + 0x1c]
0041f3ca  PUSH                   PUSH 0x0
0041f3cc  PUSH                   PUSH EBX
0041f3cd  CALL                   CALL 0x00435620
0041f3d2  MOV                    MOV ECX,EAX
0041f3d4  CALL                   CALL 0x0043ffe0
0041f3d9  MOV                    MOV EDI,dword ptr [ESI + 0x38]
0041f3dc  MOV                    MOV ECX,dword ptr [0x004fe7ac]
0041f3e2  SHL                    SHL EDI,0x18
0041f3e5  OR                     OR EDI,EBX
0041f3e7  MOV                    MOV EBX,dword ptr [ESP + 0x1c]
0041f3eb  PUSH                   PUSH EBX
0041f3ec  PUSH                   PUSH EDI
0041f3ed  PUSH                   PUSH 0x3e8
0041f3f2  CALL                   CALL 0x0043c5e0
0041f3f7  MOV                    MOV ECX,dword ptr [0x004fe7ac]
0041f3fd  PUSH                   PUSH ESI
0041f3fe  PUSH                   PUSH EDI
0041f3ff  PUSH                   PUSH 0x3e8
0041f404  CALL                   CALL 0x0043c5e0
0041f409  MOV                    MOV EDX,dword ptr [EBX + 0xc]
0041f40c  MOV                    MOV EAX,dword ptr [EDX + 0x78]
0041f40f  PUSH                   PUSH EAX
0041f410  PUSH                   PUSH 0x19
0041f412  CALL                   CALL 0x0042f9b0
0041f417  MOV                    MOV EDI,dword ptr [ESP + 0x20]
0041f41b  ADD                    ADD ESP,0x8
0041f41e  PUSH                   PUSH 0x0
0041f420  PUSH                   PUSH EDI
0041f421  MOV                    MOV ECX,ESI
0041f423  CALL                   CALL 0x00436810
0041f428  PUSH                   PUSH 0x4fdb20
0041f42d  PUSH                   PUSH 0x3ea
0041f432  MOV                    MOV ECX,0x5090b0
0041f437  MOV                    MOV dword ptr [0x004fdb20],ESI
0041f43d  MOV                    MOV dword ptr [0x004fdb24],EBX
0041f443  MOV                    MOV dword ptr [0x004fdb34],EBP
0041f449  CALL                   CALL 0x0042ab30
0041f44e  MOV                    MOV ECX,dword ptr [EBX + 0x38]
0041f451  SHL                    SHL ECX,0x8
0041f454  PUSH                   PUSH ESI
0041f455  OR                     OR ECX,EDI
0041f457  PUSH                   PUSH ECX
0041f458  MOV                    MOV ECX,dword ptr [0x004fe7ac]
0041f45e  PUSH                   PUSH 0x404
0041f463  CALL                   CALL 0x0043c5e0
0041f468  POP                    POP EBP
0041f469  POP                    POP EDI
0041f46a  POP                    POP ESI
0041f46b  XOR                    XOR EAX,EAX
0041f46d  POP                    POP EBX
0041f46e  RET                    RET
0041f46f  POP                    POP EDI
0041f470  POP                    POP ESI
0041f471  MOV                    MOV EAX,0x1
0041f476  POP                    POP EBX
0041f477  RET                    RET
0041f480  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041f484  TEST                   TEST EAX,EAX
0041f486  PUSH                   PUSH EBX
0041f487  PUSH                   PUSH ESI
0041f488  MOV                    MOV EBX,0x1
0041f48d  JZ                     JZ 0x0041f494
0041f48f  MOV                    MOV EBX,0x2
0041f494  MOV                    MOV EAX,dword ptr [ESP + 0x18]
0041f498  LEA                    LEA EAX,[EAX + EAX*0x2]
0041f49b  LEA                    LEA ESI,[EAX + EAX*0x4]
0041f49e  SHL                    SHL ESI,0x5
0041f4a1  ADD                    ADD ESI,0x4f1b10
0041f4a7  PUSH                   PUSH 0x1
0041f4a9  MOV                    MOV ECX,ESI
0041f4ab  CALL                   CALL 0x00435fe0
0041f4b0  TEST                   TEST EAX,EAX
0041f4b2  JZ                     JZ 0x0041f4bc
0041f4b4  POP                    POP ESI
0041f4b5  MOV                    MOV EAX,0x1
0041f4ba  POP                    POP EBX
0041f4bb  RET                    RET
0041f4bc  PUSH                   PUSH EBP
0041f4bd  PUSH                   PUSH EDI
0041f4be  MOV                    MOV EDI,dword ptr [0x00508e64]
0041f4c4  IMUL                   IMUL EDI,EBX
0041f4c7  PUSH                   PUSH EDI
0041f4c8  PUSH                   PUSH 0x8
0041f4ca  MOV                    MOV ECX,ESI
0041f4cc  CALL                   CALL 0x00435f80
0041f4d1  MOV                    MOV EBX,dword ptr [ESP + 0x1c]
0041f4d5  PUSH                   PUSH ESI
0041f4d6  PUSH                   PUSH 0x0
0041f4d8  PUSH                   PUSH 0x3
0041f4da  MOV                    MOV ECX,EBX
0041f4dc  CALL                   CALL 0x00434e60
0041f4e1  MOV                    MOV EAX,dword ptr [EBX + 0xc]
0041f4e4  MOV                    MOV ECX,dword ptr [EAX + 0x78]
0041f4e7  PUSH                   PUSH ECX
0041f4e8  PUSH                   PUSH 0x1a
0041f4ea  CALL                   CALL 0x0042f9b0
0041f4ef  MOV                    MOV EBP,dword ptr [ESP + 0x20]
0041f4f3  ADD                    ADD ESP,0x8
0041f4f6  PUSH                   PUSH 0x0
0041f4f8  PUSH                   PUSH EBP
0041f4f9  MOV                    MOV ECX,ESI
0041f4fb  CALL                   CALL 0x00436810
0041f500  PUSH                   PUSH 0x4fdb20
0041f505  PUSH                   PUSH 0x3eb
0041f50a  MOV                    MOV ECX,0x5090b0
0041f50f  MOV                    MOV dword ptr [0x004fdb20],ESI
0041f515  MOV                    MOV dword ptr [0x004fdb24],EBX
0041f51b  MOV                    MOV dword ptr [0x004fdb34],EDI
0041f521  CALL                   CALL 0x0042ab30
0041f526  MOV                    MOV EDX,dword ptr [EBX + 0x38]
0041f529  MOV                    MOV ECX,dword ptr [0x004fe7ac]
0041f52f  SHL                    SHL EDX,0x8
0041f532  PUSH                   PUSH ESI
0041f533  OR                     OR EDX,EBP
0041f535  PUSH                   PUSH EDX
0041f536  PUSH                   PUSH 0x404
0041f53b  CALL                   CALL 0x0043c5e0
0041f540  POP                    POP EDI
0041f541  POP                    POP EBP
0041f542  POP                    POP ESI
0041f543  XOR                    XOR EAX,EAX
0041f545  POP                    POP EBX
0041f546  RET                    RET
0041f550  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041f554  TEST                   TEST EAX,EAX
0041f556  PUSH                   PUSH EBX
0041f557  PUSH                   PUSH EBP
0041f558  PUSH                   PUSH EDI
0041f559  MOV                    MOV EBP,0x1
0041f55e  JZ                     JZ 0x0041f565
0041f560  MOV                    MOV EBP,0x2
0041f565  MOV                    MOV EDI,dword ptr [ESP + 0x18]
0041f569  MOV                    MOV EAX,dword ptr [EDI + 0xc]
0041f56c  MOV                    MOV EBX,dword ptr [EAX + 0x78]
0041f56f  MOV                    MOV AL,byte ptr [EBX + 0x30]
0041f572  TEST                   TEST AL,AL
0041f574  JZ                     JZ 0x0041f57f
0041f576  POP                    POP EDI
0041f577  POP                    POP EBP
0041f578  MOV                    MOV EAX,0x1
0041f57d  POP                    POP EBX
0041f57e  RET                    RET
0041f57f  PUSH                   PUSH ESI
0041f580  PUSH                   PUSH 0x40080000
0041f585  PUSH                   PUSH 0x0
0041f587  PUSH                   PUSH 0x5
0041f589  CALL                   CALL 0x00427d70
0041f58e  ADD                    ADD ESP,0xc
0041f591  PUSH                   PUSH EDI
0041f592  MOV                    MOV ESI,EAX
0041f594  PUSH                   PUSH 0x3ec
0041f599  PUSH                   PUSH EBP
0041f59a  MOV                    MOV dword ptr [ESI + 0x18],0x0
0041f5a1  PUSH                   PUSH EBX
0041f5a2  MOV                    MOV ECX,ESI
0041f5a4  MOV                    MOV dword ptr [ESI + 0x1c],0x3ff00000
0041f5ab  MOV                    MOV dword ptr [ESI + 0x1b4],EDI
0041f5b1  CALL                   CALL 0x00428330
0041f5b6  MOV                    MOV ECX,ESI
0041f5b8  CALL                   CALL 0x00428380
0041f5bd  MOV                    MOV ECX,dword ptr [EDI + 0xc]
0041f5c0  MOV                    MOV EDX,dword ptr [ECX + 0x78]
0041f5c3  PUSH                   PUSH EDX
0041f5c4  PUSH                   PUSH 0x1b
0041f5c6  CALL                   CALL 0x0042f9b0
0041f5cb  ADD                    ADD ESP,0x8
0041f5ce  MOV                    MOV dword ptr [0x004fdb20],EDI
0041f5d4  MOV                    MOV EAX,dword ptr [EBX + 0x3c]
0041f5d7  PUSH                   PUSH 0x4fdb20
0041f5dc  PUSH                   PUSH 0x3ec
0041f5e1  MOV                    MOV ECX,0x5090b0
0041f5e6  MOV                    MOV [0x004fdb3c],EAX
0041f5eb  CALL                   CALL 0x0042ab30
0041f5f0  POP                    POP ESI
0041f5f1  POP                    POP EDI
0041f5f2  POP                    POP EBP
0041f5f3  XOR                    XOR EAX,EAX
0041f5f5  POP                    POP EBX
0041f5f6  RET                    RET
0041f600  MOV                    MOV EAX,dword ptr [ESP + 0x4]
0041f604  TEST                   TEST EAX,EAX
0041f606  PUSH                   PUSH EBX
0041f607  PUSH                   PUSH EBP
0041f608  PUSH                   PUSH ESI
0041f609  PUSH                   PUSH EDI
0041f60a  MOV                    MOV EBP,0x1
0041f60f  JZ                     JZ 0x0041f616
0041f611  MOV                    MOV EBP,0x2
0041f616  MOV                    MOV EDI,dword ptr [ESP + 0x1c]
0041f61a  MOV                    MOV EAX,dword ptr [EDI + 0xc]
0041f61d  MOV                    MOV EBX,dword ptr [EAX + 0x78]
0041f620  PUSH                   PUSH 0x40080000
0041f625  PUSH                   PUSH 0x0
0041f627  PUSH                   PUSH 0x2
0041f629  CALL                   CALL 0x00427d70
0041f62e  ADD                    ADD ESP,0xc
0041f631  PUSH                   PUSH EDI
0041f632  MOV                    MOV ESI,EAX
0041f634  PUSH                   PUSH 0x3ed
0041f639  PUSH                   PUSH EBP
0041f63a  MOV                    MOV dword ptr [ESI + 0x18],0x0
0041f641  PUSH                   PUSH EBX
0041f642  MOV                    MOV ECX,ESI
0041f644  MOV                    MOV dword ptr [ESI + 0x1c],0x3ff00000
0041f64b  MOV                    MOV dword ptr [ESI + 0x1b4],EDI
0041f651  CALL                   CALL 0x00428330
0041f656  MOV                    MOV ECX,ESI
0041f658  CALL                   CALL 0x00428050
0041f65d  MOV                    MOV ECX,dword ptr [EDI + 0xc]
0041f660  MOV                    MOV EDX,dword ptr [ECX + 0x78]
0041f663  PUSH                   PUSH EDX
0041f664  PUSH                   PUSH 0x1c
0041f666  CALL                   CALL 0x0042f9b0
0041f66b  ADD                    ADD ESP,0x8
0041f66e  MOV                    MOV dword ptr [0x004fdb20],EDI
0041f674  MOV                    MOV EAX,dword ptr [EBX + 0x3c]
0041f677  PUSH                   PUSH 0x4fdb20
0041f67c  PUSH                   PUSH 0x3ed
0041f681  MOV                    MOV ECX,0x5090b0
0041f686  MOV                    MOV [0x004fdb3c],EAX
0041f68b  CALL                   CALL 0x0042ab30
0041f690  POP                    POP EDI
0041f691  POP                    POP ESI
0041f692  POP                    POP EBP
0041f693  XOR                    XOR EAX,EAX
0041f695  POP                    POP EBX
0041f696  RET                    RET
0041f6a0  MOV                    MOV ECX,dword ptr [ESP + 0x4]
0041f6a4  TEST                   TEST ECX,ECX
0041f6a6  MOV                    MOV EAX,0x1
0041f6ab  JZ                     JZ 0x0041f6b2


// ===== 421300 → 不是已识别函数（可能只被函数指针引用）→ 改为线性反汇编

00421300  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421304  PUSH                   PUSH 0x3
00421306  PUSH                   PUSH EAX
00421307  CALL                   CALL 0x00421240
0042130c  ADD                    ADD ESP,0x8
0042130f  RET                    RET
00421310  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421314  PUSH                   PUSH 0x4
00421316  PUSH                   PUSH EAX
00421317  CALL                   CALL 0x00421240
0042131c  ADD                    ADD ESP,0x8
0042131f  RET                    RET
00421320  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421324  PUSH                   PUSH 0x5
00421326  PUSH                   PUSH EAX
00421327  CALL                   CALL 0x00421240
0042132c  ADD                    ADD ESP,0x8
0042132f  RET                    RET
00421330  MOV                    MOV EAX,[0x004f2a30]
00421335  TEST                   TEST EAX,EAX
00421337  PUSH                   PUSH ESI
00421338  JZ                     JZ 0x0042134e
0042133a  PUSH                   PUSH 0x5
0042133c  PUSH                   PUSH 0x1
0042133e  CALL                   CALL 0x00405130
00421343  ADD                    ADD ESP,0x8
00421346  DEC                    DEC EAX
00421347  NEG                    NEG EAX
00421349  SBB                    SBB EAX,EAX
0042134b  INC                    INC EAX
0042134c  POP                    POP ESI
0042134d  RET                    RET
0042134e  MOV                    MOV ESI,dword ptr [ESP + 0x8]
00421352  MOV                    MOV EAX,dword ptr [ESI + 0xc]
00421355  MOV                    MOV EDX,dword ptr [EAX + 0x74]
00421358  MOV                    MOV EAX,dword ptr [EAX + 0x78]
0042135b  PUSH                   PUSH ESI
0042135c  PUSH                   PUSH EDX
0042135d  PUSH                   PUSH 0x7
0042135f  MOV                    MOV ECX,EAX
00421361  CALL                   CALL 0x0042bbf0
00421366  CMP                    CMP EAX,0x5
00421369  JL                     JL 0x0042138b
0042136b  MOV                    MOV EAX,dword ptr [ESI + 0xc]
0042136e  MOV                    MOV EDX,dword ptr [EAX + 0x74]
00421371  MOV                    MOV EAX,dword ptr [EAX + 0x78]
00421374  PUSH                   PUSH ESI
00421375  PUSH                   PUSH EDX
00421376  PUSH                   PUSH 0x7
00421378  MOV                    MOV ECX,EAX
0042137a  CALL                   CALL 0x0042bbf0
0042137f  CMP                    CMP EAX,0x2
00421382  JG                     JG 0x0042138b
00421384  MOV                    MOV EAX,0x1
00421389  POP                    POP ESI
0042138a  RET                    RET
0042138b  XOR                    XOR EAX,EAX
0042138d  POP                    POP ESI
0042138e  RET                    RET
00421390  MOV                    MOV EDX,dword ptr [ESP + 0x4]
00421394  MOV                    MOV EAX,dword ptr [EDX + 0xc]
00421397  PUSH                   PUSH ESI
00421398  MOV                    MOV ESI,dword ptr [EAX + 0x74]
0042139b  MOV                    MOV EAX,dword ptr [EAX + 0x78]
0042139e  PUSH                   PUSH EDX
0042139f  PUSH                   PUSH ESI
004213a0  PUSH                   PUSH 0xa
004213a2  MOV                    MOV ECX,EAX
004213a4  CALL                   CALL 0x0042bbf0
004213a9  XOR                    XOR ECX,ECX
004213ab  CMP                    CMP EAX,0x7
004213ae  SETGE                  SETGE CL
004213b1  POP                    POP ESI
004213b2  MOV                    MOV EAX,ECX
004213b4  RET                    RET
004213c0  PUSH                   PUSH EBX
004213c1  PUSH                   PUSH EBP
004213c2  PUSH                   PUSH ESI
004213c3  MOV                    MOV ESI,dword ptr [ESP + 0x10]
004213c7  PUSH                   PUSH EDI
004213c8  PUSH                   PUSH 0x3
004213ca  MOV                    MOV ECX,ESI
004213cc  CALL                   CALL 0x00436230
004213d1  TEST                   TEST EAX,EAX
004213d3  JZ                     JZ 0x00421445
004213d5  MOV                    MOV EAX,dword ptr [ESI + 0xc]
004213d8  MOV                    MOV ESI,dword ptr [EAX + 0x78]
004213db  MOV                    MOV EBP,dword ptr [EAX + 0x74]
004213de  MOV                    MOV EBX,0x1
004213e3  MOV                    MOV EAX,dword ptr [ESP + 0x18]
004213e7  PUSH                   PUSH 0x1
004213e9  PUSH                   PUSH EBP
004213ea  MOV                    MOV ECX,ESI
004213ec  MOV                    MOV dword ptr [EAX],EBX
004213ee  CALL                   CALL 0x0042bb70
004213f3  MOV                    MOV ESI,EAX
004213f5  MOV                    MOV EAX,dword ptr [ESI + 0x30]
004213f8  CMP                    CMP EAX,0x4
004213fb  JZ                     JZ 0x0042144c
004213fd  CMP                    CMP EAX,0x10
00421400  JZ                     JZ 0x0042144c
00421402  CMP                    CMP EAX,0x7
00421405  JZ                     JZ 0x0042144c
00421407  MOV                    MOV ECX,ESI
00421409  CALL                   CALL 0x0042bb50
0042140e  MOV                    MOV EDI,EAX
00421410  TEST                   TEST EDI,EDI
00421412  JZ                     JZ 0x0042143f
00421414  MOV                    MOV EAX,dword ptr [EDI + 0x34]
00421417  TEST                   TEST EAX,EAX
00421419  JZ                     JZ 0x0042144c
0042141b  MOV                    MOV ECX,dword ptr [ESP + 0x14]
0042141f  CALL                   CALL 0x00435620
00421424  CMP                    CMP dword ptr [EDI + 0x34],EAX
00421427  JNZ                    JNZ 0x0042143f
00421429  MOV                    MOV EDI,dword ptr [EDI + 0x30]
0042142c  TEST                   TEST EDI,EDI
0042142e  JZ                     JZ 0x0042144c
00421430  PUSH                   PUSH EDI
00421431  MOV                    MOV ECX,0x4ece18
00421436  CALL                   CALL 0x0041ce40
0042143b  TEST                   TEST EAX,EAX
0042143d  JNZ                    JNZ 0x0042144c
0042143f  INC                    INC EBX
00421440  CMP                    CMP EBX,0x5
00421443  JLE                    JLE 0x004213e3
00421445  POP                    POP EDI
00421446  POP                    POP ESI
00421447  POP                    POP EBP
00421448  XOR                    XOR EAX,EAX
0042144a  POP                    POP EBX
0042144b  RET                    RET
0042144c  POP                    POP EDI
0042144d  POP                    POP ESI
0042144e  POP                    POP EBP
0042144f  MOV                    MOV EAX,0x1
00421454  POP                    POP EBX
00421455  RET                    RET
00421460  PUSH                   PUSH EBX
00421461  MOV                    MOV EBX,dword ptr [ESP + 0x8]
00421465  MOV                    MOV EAX,dword ptr [EBX + 0xc]
00421468  MOV                    MOV ECX,dword ptr [EAX + 0x78]
0042146b  PUSH                   PUSH ESI
0042146c  PUSH                   PUSH EDI
0042146d  CALL                   CALL 0x0042bb50
00421472  MOV                    MOV ESI,EAX
00421474  TEST                   TEST ESI,ESI
00421476  JZ                     JZ 0x004214d4
00421478  MOV                    MOV EAX,dword ptr [ESI + 0x30]
0042147b  TEST                   TEST EAX,EAX
0042147d  JZ                     JZ 0x004214d4
0042147f  MOV                    MOV EDI,dword ptr [ESI + 0x34]
00421482  MOV                    MOV ECX,EBX
00421484  CALL                   CALL 0x00435620
00421489  CMP                    CMP EDI,EAX
0042148b  JZ                     JZ 0x004214d4
0042148d  TEST                   TEST EDI,EDI
0042148f  JZ                     JZ 0x004214d4
00421491  MOV                    MOV ECX,dword ptr [ESI + 0x30]
00421494  PUSH                   PUSH ECX
00421495  MOV                    MOV ECX,0x4ece18
0042149a  CALL                   CALL 0x0041ce40
0042149f  TEST                   TEST EAX,EAX
004214a1  JNZ                    JNZ 0x004214d4
004214a3  MOV                    MOV EDX,dword ptr [ESI + 0x30]
004214a6  CMP                    CMP dword ptr [EDX + 0x38],0x3
004214aa  JGE                    JGE 0x004214d4
004214ac  PUSH                   PUSH 0x2
004214ae  PUSH                   PUSH 0x0
004214b0  CALL                   CALL 0x00405130
004214b5  MOV                    MOV ECX,dword ptr [ESI + 0x30]
004214b8  MOV                    MOV ECX,dword ptr [ECX + 0x34]
004214bb  ADD                    ADD ESP,0x8
004214be  LEA                    LEA EDX,[ECX + ECX*0x2]
004214c1  MOV                    MOV ECX,dword ptr [ESP + 0x14]
004214c5  POP                    POP EDI
004214c6  LEA                    LEA EAX,[EAX + EDX*0x1 + -0x3]
004214ca  POP                    POP ESI
004214cb  MOV                    MOV dword ptr [ECX],EAX
004214cd  MOV                    MOV EAX,0x1
004214d2  POP                    POP EBX
004214d3  RET                    RET
004214d4  POP                    POP EDI
004214d5  POP                    POP ESI
004214d6  XOR                    XOR EAX,EAX
004214d8  POP                    POP EBX
004214d9  RET                    RET
004214e0  PUSH                   PUSH EBX
004214e1  MOV                    MOV EBX,dword ptr [ESP + 0x8]
004214e5  MOV                    MOV EAX,dword ptr [EBX + 0xc]
004214e8  PUSH                   PUSH ESI
004214e9  PUSH                   PUSH EDI
004214ea  MOV                    MOV EDI,dword ptr [EAX + 0x78]
004214ed  MOV                    MOV ECX,EDI
004214ef  CALL                   CALL 0x0042bb50
004214f4  MOV                    MOV ESI,EAX
004214f6  TEST                   TEST ESI,ESI
004214f8  JZ                     JZ 0x0042154b
004214fa  MOV                    MOV EAX,dword ptr [ESI + 0x30]
004214fd  TEST                   TEST EAX,EAX
004214ff  JZ                     JZ 0x0042154b
00421501  MOV                    MOV ECX,EBX
00421503  CALL                   CALL 0x00435620
00421508  CMP                    CMP dword ptr [ESI + 0x34],EAX
0042150b  JNZ                    JNZ 0x0042154b
0042150d  MOV                    MOV ECX,dword ptr [ESI + 0x30]
00421510  PUSH                   PUSH ECX
00421511  MOV                    MOV ECX,0x4ece18
00421516  CALL                   CALL 0x0041ce40
0042151b  TEST                   TEST EAX,EAX
0042151d  JZ                     JZ 0x0042154b
0042151f  MOV                    MOV EDX,dword ptr [EDI + 0x28]
00421522  SUB                    SUB EDX,dword ptr [0x004e3844]
00421528  MOV                    MOV EAX,0xba2e8ba3
0042152d  MUL                    MUL EDX
0042152f  MOV                    MOV EAX,dword ptr [ESP + 0x14]
00421533  SHR                    SHR EDX,0x6
00421536  MOV                    MOV dword ptr [EAX],EDX
00421538  MOV                    MOV ECX,dword ptr [EDI + 0x2c]
0042153b  SHL                    SHL ECX,0x10
0042153e  POP                    POP EDI
0042153f  OR                     OR ECX,EDX
00421541  POP                    POP ESI
00421542  MOV                    MOV dword ptr [EAX],ECX
00421544  MOV                    MOV EAX,0x1
00421549  POP                    POP EBX
0042154a  RET                    RET
0042154b  POP                    POP EDI
0042154c  POP                    POP ESI
0042154d  XOR                    XOR EAX,EAX
0042154f  POP                    POP EBX
00421550  RET                    RET
00421560  PUSH                   PUSH EBX
00421561  PUSH                   PUSH ESI
00421562  MOV                    MOV ESI,dword ptr [ESP + 0xc]
00421566  PUSH                   PUSH EDI
00421567  MOV                    MOV ECX,ESI
00421569  CALL                   CALL 0x00436080
0042156e  MOV                    MOV EBX,EAX
00421570  TEST                   TEST EBX,EBX
00421572  JZ                     JZ 0x004215d8
00421574  MOV                    MOV EAX,dword ptr [ESI + 0xc]
00421577  MOV                    MOV EDI,dword ptr [EAX + 0x78]
0042157a  MOV                    MOV ECX,EDI
0042157c  CALL                   CALL 0x0042bb50
00421581  MOV                    MOV ESI,EAX
00421583  TEST                   TEST ESI,ESI
00421585  JZ                     JZ 0x004215d8
00421587  MOV                    MOV EAX,dword ptr [ESI + 0x30]
0042158a  TEST                   TEST EAX,EAX
0042158c  JZ                     JZ 0x004215d8
0042158e  MOV                    MOV ECX,EBX
00421590  CALL                   CALL 0x00435620
00421595  CMP                    CMP dword ptr [ESI + 0x34],EAX
00421598  JNZ                    JNZ 0x004215d8
0042159a  MOV                    MOV ECX,dword ptr [ESI + 0x30]
0042159d  PUSH                   PUSH ECX
0042159e  MOV                    MOV ECX,0x4ece18
004215a3  CALL                   CALL 0x0041ce40
004215a8  TEST                   TEST EAX,EAX
004215aa  JNZ                    JNZ 0x004215d8
004215ac  MOV                    MOV EDX,dword ptr [EDI + 0x28]
004215af  SUB                    SUB EDX,dword ptr [0x004e3844]
004215b5  MOV                    MOV EAX,0xba2e8ba3
004215ba  MUL                    MUL EDX
004215bc  MOV                    MOV EAX,dword ptr [ESP + 0x14]
004215c0  SHR                    SHR EDX,0x6
004215c3  MOV                    MOV dword ptr [EAX],EDX
004215c5  MOV                    MOV ECX,dword ptr [EDI + 0x2c]
004215c8  SHL                    SHL ECX,0x10
004215cb  POP                    POP EDI
004215cc  OR                     OR ECX,EDX
004215ce  POP                    POP ESI
004215cf  MOV                    MOV dword ptr [EAX],ECX
004215d1  MOV                    MOV EAX,0x1
004215d6  POP                    POP EBX
004215d7  RET                    RET
004215d8  POP                    POP EDI
004215d9  POP                    POP ESI
004215da  XOR                    XOR EAX,EAX
004215dc  POP                    POP EBX
004215dd  RET                    RET
004215e0  PUSH                   PUSH ESI
004215e1  PUSH                   PUSH EDI
004215e2  MOV                    MOV EDI,dword ptr [ESP + 0xc]
004215e6  MOV                    MOV EAX,dword ptr [EDI + 0xc]
004215e9  MOV                    MOV ECX,dword ptr [EAX + 0x78]
004215ec  CALL                   CALL 0x0042bb50
004215f1  MOV                    MOV ESI,EAX
004215f3  TEST                   TEST ESI,ESI
004215f5  JZ                     JZ 0x00421659
004215f7  MOV                    MOV ECX,EDI
004215f9  CALL                   CALL 0x00435620
004215fe  CMP                    CMP dword ptr [ESI + 0x34],EAX
00421601  JZ                     JZ 0x00421659
00421603  MOV                    MOV EAX,dword ptr [ESI + 0x30]
00421606  TEST                   TEST EAX,EAX
00421608  JZ                     JZ 0x00421610
0042160a  CMP                    CMP dword ptr [EAX + 0x34],0x1
0042160e  JG                     JG 0x00421659
00421610  MOV                    MOV ECX,EDI
00421612  CALL                   CALL 0x00436080
00421617  TEST                   TEST EAX,EAX
00421619  JZ                     JZ 0x00421659
0042161b  MOV                    MOV ECX,dword ptr [ESI + 0x30]
0042161e  TEST                   TEST ECX,ECX
00421620  JZ                     JZ 0x00421659
00421622  MOV                    MOV ECX,EAX
00421624  CALL                   CALL 0x00435620
00421629  CMP                    CMP dword ptr [ESI + 0x34],EAX
0042162c  JNZ                    JNZ 0x00421659
0042162e  MOV                    MOV ECX,dword ptr [ESI + 0x30]
00421631  PUSH                   PUSH ECX
00421632  MOV                    MOV ECX,0x4ece18
00421637  CALL                   CALL 0x0041ce40
0042163c  TEST                   TEST EAX,EAX
0042163e  JNZ                    JNZ 0x00421648
00421640  POP                    POP EDI
00421641  MOV                    MOV EAX,0x1
00421646  POP                    POP ESI
00421647  RET                    RET
00421648  MOV                    MOV EDX,dword ptr [ESI + 0x30]
0042164b  MOV                    MOV ECX,dword ptr [EDX + 0x30]
0042164e  XOR                    XOR EAX,EAX
00421650  CMP                    CMP ECX,0x3
00421653  POP                    POP EDI
00421654  SETGE                  SETGE AL
00421657  POP                    POP ESI
00421658  RET                    RET
00421659  POP                    POP EDI
0042165a  XOR                    XOR EAX,EAX
0042165c  POP                    POP ESI
0042165d  RET                    RET
00421660  MOV                    MOV ECX,dword ptr [ESP + 0x4]
00421664  MOV                    MOV EAX,dword ptr [ECX + 0xc]
00421667  MOV                    MOV EDX,dword ptr [EAX + 0x78]
0042166a  PUSH                   PUSH ESI
0042166b  MOV                    MOV ESI,dword ptr [EDX + 0x3c]
0042166e  TEST                   TEST ESI,ESI
00421670  JNZ                    JNZ 0x00421676
00421672  XOR                    XOR EAX,EAX
00421674  POP                    POP ESI
00421675  RET                    RET
00421676  PUSH                   PUSH EDI
00421677  CALL                   CALL 0x00435620
0042167c  PUSH                   PUSH EAX
0042167d  PUSH                   PUSH 0x0
0042167f  MOV                    MOV ECX,ESI
00421681  CALL                   CALL 0x0042ec80
00421686  PUSH                   PUSH 0x0
00421688  PUSH                   PUSH 0x0
0042168a  MOV                    MOV ECX,ESI
0042168c  MOV                    MOV EDI,EAX
0042168e  CALL                   CALL 0x0042ec80
00421693  MOV                    MOV dword ptr [ESP + 0xc],EAX
00421697  FILD                   FILD dword ptr [ESP + 0xc]
0042169b  FMUL                   FMUL float ptr [0x00495b54]
004216a1  CALL                   CALL 0x004853d4
004216a6  XOR                    XOR ECX,ECX
004216a8  CMP                    CMP EDI,EAX
004216aa  SETGE                  SETGE CL
004216ad  POP                    POP EDI
004216ae  POP                    POP ESI
004216af  MOV                    MOV EAX,ECX
004216b1  RET                    RET
004216c0  MOV                    MOV ECX,dword ptr [ESP + 0x4]
004216c4  MOV                    MOV EAX,dword ptr [ECX + 0xc]
004216c7  MOV                    MOV EDX,dword ptr [EAX + 0x78]
004216ca  PUSH                   PUSH ESI
004216cb  MOV                    MOV ESI,dword ptr [EDX + 0x3c]
004216ce  TEST                   TEST ESI,ESI
004216d0  JNZ                    JNZ 0x004216d6
004216d2  XOR                    XOR EAX,EAX
004216d4  POP                    POP ESI
004216d5  RET                    RET
004216d6  PUSH                   PUSH EDI
004216d7  CALL                   CALL 0x00435620
004216dc  PUSH                   PUSH EAX
004216dd  PUSH                   PUSH 0x0
004216df  MOV                    MOV ECX,ESI
004216e1  CALL                   CALL 0x0042ec80
004216e6  PUSH                   PUSH 0x0
004216e8  PUSH                   PUSH 0x0
004216ea  MOV                    MOV ECX,ESI
004216ec  MOV                    MOV EDI,EAX
004216ee  CALL                   CALL 0x0042ec80
004216f3  MOV                    MOV dword ptr [ESP + 0xc],EAX
004216f7  FILD                   FILD dword ptr [ESP + 0xc]
004216fb  FMUL                   FMUL float ptr [0x004955ec]
00421701  CALL                   CALL 0x004853d4
00421706  XOR                    XOR ECX,ECX
00421708  CMP                    CMP EDI,EAX
0042170a  SETLE                  SETLE CL
0042170d  POP                    POP EDI
0042170e  POP                    POP ESI
0042170f  MOV                    MOV EAX,ECX
00421711  RET                    RET
00421720  MOV                    MOV EAX,dword ptr [ESP + 0x4]
00421724  MOV                    MOV EAX,dword ptr [EAX + 0xc]
00421727  MOV                    MOV EDX,dword ptr [EAX + 0x74]


