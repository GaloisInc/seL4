#
# Copyright 2017, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the GNU General Public License version 2. Note that NO WARRANTY is provided.
# See "LICENSE_GPLv2.txt" for details.
#
# @TAG(DATA61_GPL)
#

cmake_minimum_required(VERSION 3.7.2)

config_choice(KernelX86Sel4Arch X86_SEL4_ARCH "Architecture mode for building the kernel"
    "x86_64;KernelSel4ArchX86_64;ARCH_X86_64;KernelArchX86"
    "ia32;KernelSel4ArchIA32;ARCH_IA32;KernelArchX86"
)

if(KernelArchX86)
    # Only one platform so just force it to be set
    config_set(KernelPlatform PLAT "pc99")
    config_set(KernelPlatPC99 PLAT_PC99 ON)
    config_set(KernelSel4Arch SEL4_ARCH "${KernelX86Sel4Arch}")
    # x86 always has an FPU
    set(KernelHaveFPU ON)
else()
    config_set(KernelPlatPC99 PLAT_PC99 OFF)
endif()

if(KernelSel4ArchX86_64)
    set_kernel_64()
elseif(KernelSel4ArchIA32)
    set_kernel_32()
endif()

config_choice(KernelX86MicroArch KERNEL_X86_MICRO_ARCH "Select the x86 micro architecture"
    "nehalem;KernelX86MicroArchNehalem;ARCH_X86_NEHALEM;KernelArchX86"
    "generic;KernelX86MicroArchGeneric;ARCH_X86_GENERIC;KernelArchX86"
    "westmere;KernelX86MicroArchWestmere;ARCH_X86_WESTMERE;KernelArchX86"
    "sandy;KernelX86MicroArchSandy;ARCH_X86_SANDY;KernelArchX86"
    "ivy;KernelX86MicroArchIvy;ARCH_X86_IVY;KernelArchX86"
    "haswell;KernelX86MicroArchHaswell;ARCH_X86_HASWELL;KernelArchX86"
    "broadwell;KernelX86MicroArchBroadwell;ARCH_X86_BROADWELL;KernelArchX86"
    "skylake;KernelX86MicroArchSkylake;ARCH_X86_SKYLAKE;KernelArchX86"
)

config_choice(KernelIRQController KERNEL_IRQ_CONTROLLER
    "Select the IRQ controller seL4 will use. Code for others may still be included if \
    needed to disable at run time. \
    PIC -> Use the legacy PIC controller. \
    IOAPIC -> Use one or more IOAPIC controllers"
    "IOAPIC;KernelIRQControllerIOAPIC;IRQ_IOAPIC;KernelArchX86"
    "PIC;KernelIRQControllerPIC;IRQ_PIC;KernelArchX86"
)

config_string(KernelMaxNumIOAPIC MAX_NUM_IOAPIC
    "Configure the maximum number of IOAPIC controllers that can be supported. SeL4 \
    will detect IOAPICs regardless of whether the IOAPIC will actually be used as \
    the final IRQ controller."
    DEFAULT 1
    DEPENDS "KernelIRQControllerIOAPIC" DEFAULT_DISABLED 0
    UNQUOTE
)

config_choice(KernelLAPICMode KERNEL_LAPIC_MODE
    "Select the mode local APIC will use. Not all machines support X2APIC mode."
    "XAPIC;KernelLAPICModeXPAIC;XAPIC;KernelArchX86"
    "X2APIC;KernelLAPICModeX2APIC;X2APIC;KernelArchX86"
)

config_option(KernelUseLogcalIDs USE_LOGCAL_IDS
    "Use logical IDs to broadcast IPI between cores. Not all machines support logical \
    IDs. In xAPIC mode only 8 cores can be addressed using logical IDs."
    DEFAULT OFF
    DEPENDS "NOT ${KernelMaxNumNodes} EQUAL 1;KernelArchX86"
)

config_string(KernelCacheLnSz CACHE_LN_SZ
    "Define cache line size for the current architecture"
    DEFAULT 64
    DEPENDS "KernelArchX86" UNDEF_DISABLED
    UNQUOTE
)

config_option(KernelVTX VTX
    "VTX support"
    DEFAULT OFF
    DEPENDS "KernelArchX86;NOT KernelVerificationBuild"
)

config_string(KernelMaxVPIDs MAX_VPIDS
    "The kernel maintains a mapping of 16-bit VPIDs to VCPUs. This option should be \
    sized as small as possible to save memory, but be at least the number of VCPUs that \
    will be run for optimum performance."
    DEFAULT 1024
    DEPENDS "KernelVTX" DEFAULT_DISABLED 0
    UNQUOTE
)

config_option(KernelHugePage HUGE_PAGE
    "Add support for 1GB huge page. Not all recent processor models support this feature."
    DEFAULT ON
    DEPENDS "KernelSel4ArchX86_64" DEFAULT_DISABLED OFF
)
config_option(KernelSupportPCID SUPPORT_PCID
    "Add support for PCIDs (aka hardware ASIDs). Not all processor models support this feature."
    DEFAULT ON
    DEPENDS "KernelSel4ArchX86_64" DEFAULT_DISABLED OFF
)

config_choice(KernelSyscall KERNEL_X86_SYSCALL
    "The kernel only ever supports one method of performing syscalls at a time. This \
    config should be set to the most efficient one that is support by the hardware the \
    system will run on"
    "syscall;KernelX86SyscallSyscall;SYSCALL;KernelSel4ArchX86_64"
    "sysenter;KernelX86SyscallSysenter;SYSENTER;KernelArchX86"
)

config_choice(KernelFPU KERNEL_X86_FPU "Choose the method that FPU state is stored in. This \
    directly affects the method used to save and restore it. \
    FXSAVE -> This chooses the legacy 512-byte region used by the fxsave and fxrstor functions \
    XSAVE -> This chooses the variable xsave region, and enables the ability to use any \
    of the xsave variants to save and restore. The actual size of the region is dependent on \
    the features enabled."
    "XSAVE;KernelFPUXSave;XSAVE;KernelArchX86"
    "FXSAVE;KernelFPUFXSave;FXSAVE;KernelArchX86"
)

config_choice(KernelXSave KERNEL_XSAVE "The XSAVE area supports multiple instructions to save
        and restore to it. These instructions are dependent upon specific CPU support. See Chapter 13 of Volume \
        1 of the Intel Architectures SOftware Developers Manual for discussion on the init and modified \
        optimizations. \
        XSAVE -> Original XSAVE instruction. This is the only XSAVE instruction that is guaranteed to exist if \
            XSAVE is present \
        XSAVEC -> Save state with compaction. This compaction has to do with minimizing the total size of \
            XSAVE buffer, if using non contiguous features, XSAVEC will attempt to use the init optimization \
            when saving \
        XSAVEOPT -> Save state taking advantage of both the init optimization and modified optimization \
        XSAVES -> Save state taking advantage of the modified optimization. This instruction is only \
            available in OS code, and is the preferred save method if it exists."
    "XSAVEOPT;KernelXSaveXSaveOpt;XSAVE_XSAVEOPT;KernelFPUXSave"
    "XSAVE;KernelXSaveXSave;XSAVE_XSAVE;KernelFPUXSave"
    "XSAVEC;KernelXSaveXSaveC;XSAVE_XSAVEC;KernelFPUXSave"
)
config_string(KernelXSaveFeatureSet XSAVE_FEATURE_SET
    "XSAVE can save and restore the state for various features \
    through the use of the feature mask. This config option represents the feature mask that we want to \
    support. The CPU must support all bits in this feature mask. Current known bits are \
        0 - FPU \
        1 - SSE \
        2 - AVX \
        FPU and SSE is guaranteed to exist if XSAVE exists."
    DEFAULT 3
    DEPENDS "KernelFPUXSave" DEFAULT_DISABLED 0
    UNQUOTE
)

if(KernelFPUXSave)
    set(default_xsave_size 576)
else()
    set(default_xsave_size 512)
endif()

config_string(KernelXSaveSize XSAVE_SIZE
    "The size of the XSAVE region. This is dependent upon the features in \
    XSAVE_FEATURE_SET that have been requested. Default is 576 for the FPU and SSE
    state, unless XSAVE is not in use then it should be 512 for the legacy FXSAVE region."
    DEFAULT ${default_xsave_size}
    DEPENDS "KernelArchX86" DEFAULT_DISABLED 0
    UNQUOTE
)

config_choice(KernelFSGSBase KERNEL_FSGS_BASE
    "There are three ways to to set FS/GS base addresses: \
    IA32_FS/GS_GDT, IA32_FS/GS_BASE_MSR, and fsgsbase instructions. \
    IA32_FS/GS_GDT and IA32_FS/GS_BASE_MSR are availble for 32-bit. \
    IA32_FS/GS_BASE_MSR and fsgsbase instructions are available for 64-bit."
    "inst;KernelFSGSBaseInst;FSGSBASE_INST;KernelSel4ArchX86_64"
    "gdt;KernelFSGSBaseGDT;FSGSBASE_GDT;KernelSel4ArchIA32"
    "msr;KernelFSGSBaseMSR;FSGSBASE_MSR;KernelSel4ArchX86_64"
)

config_choice(KernelMultibootGFXMode KERNEL_MUTLTIBOOT_GFX_MODE
    "The type of graphics mode to request from the boot loader. This is encoded into the \
    multiboot header and is merely a hint, the boot loader is free to ignore or set some \
    other mode"
    "none;KernelMultibootGFXModeNone;MULTIBOOT_GRAPHICS_MODE_NONE;KernelArchX86"
    "text;KernelMultibootGFXModeText;MULTIBOOT_GRAPHICS_MODE_TEXT;KernelArchX86"
    "linear;KernelMultibootGFXModeLinear;MULTIBOOT_GRAPHICS_MODE_LINEAR;KernelArchX86"
)

config_string(KernelMultibootGFXDepth MULTIBOOT_GRAPHICS_MODE_DEPTH
    "The bits per pixel of the linear graphics mode ot request. Value of zero indicates \
    no preference."
    DEFAULT 32
    DEPENDS "KernelMultibootGFXModeLinear" UNDEF_DISABLED
    UNQUOTE
)

config_string(KernelMultibootGFXWidth MULTIBOOT_GRAPHICS_MODE_WIDTH
    "The width of the graphics mode to request. For a linear graphics mode this is the \
    number of pixels. For a text mode this is the number of characters, value of zero \
    indicates no preference."
    DEFAULT 0
    DEPENDS "KernelMultibootGFXModeText OR KernelMultibootGFXModeLinear" UNDEF_DISABLED
    UNQUOTE
)
config_string(KernelMultibootGFXHeight MULTIBOOT_GRAPHICS_MODE_HEIGHT
    "The height of the graphics mode to request. For a linear graphics mode this is the \
    number of pixels. For a text mode this is the number of characters, value of zero \
    indicates no preference."
    DEFAULT 0
    DEPENDS "KernelMultibootGFXModeText OR KernelMultibootGFXModeLinear" UNDEF_DISABLED
    UNQUOTE
)

add_sources(
    DEP "KernelArchX86"
    PREFIX src/arch/x86
    CFILES
        c_traps.c
        idle.c
        api/faults.c
        object/interrupt.c
        object/ioport.c
        object/objecttype.c
        object/tcb.c
        object/iospace.c
        object/vcpu.c
        kernel/vspace.c
        kernel/apic.c
        kernel/xapic.c
        kernel/x2apic.c
        kernel/boot_sys.c
        kernel/smp_sys.c
        kernel/boot.c
        kernel/cmdline.c
        kernel/ept.c
        model/statedata.c
        machine/hardware.c
        machine/fpu.c
        machine/cpu_identification.c
        machine/breakpoint.c
        machine/registerset.c
        benchmark/benchmark.c
        smp/ipi.c
    ASMFILES
        multiboot.S
)

add_sources(
    DEP "KernelArchX86;KernelDebugBuild"
    CFILES src/arch/x86/machine/capdl.c
)

add_bf_source_old("KernelArchX86" "structures.bf" "include/arch/x86" "arch/object")

include(src/plat/pc99/config.cmake)

include(src/arch/x86/32/config.cmake)
include(src/arch/x86/64/config.cmake)
