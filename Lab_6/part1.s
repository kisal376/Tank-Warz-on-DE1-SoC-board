               .equ      EDGE_TRIGGERED,    0x1
               .equ      LEVEL_SENSITIVE,   0x0
               .equ      CPU0,              0x01    // bit-mask; bit 0 represents cpu0
               .equ      ENABLE,            0x1

               .equ      KEY0,              0b0001
               .equ      KEY1,              0b0010
               .equ      KEY2,              0b0100
               .equ      KEY3,              0b1000
			   .equ 	 HEX_BASE_0TO3,		0xFF200020
			   .equ		 KEY_BASE,			0xFF200050

               .equ      IRQ_MODE,          0b10010
               .equ      SVC_MODE,          0b10011

               .equ      INT_ENABLE,        0b01000000
               .equ      INT_DISABLE,       0b11000000
/*********************************************************************************
 * Initialize the exception vector table
 ********************************************************************************/
                .section .vectors, "ax"

                B        _start             // reset vector
                .word    0                  // undefined instruction vector
                .word    0                  // software interrrupt vector
                .word    0                  // aborted prefetch vector
                .word    0                  // aborted data vector
                .word    0                  // unused vector
                B        IRQ_HANDLER        // IRQ interrupt vector
                .word    0                  // FIQ interrupt vector

/*********************************************************************************
 * Main program
 ********************************************************************************/
                .text
                .global  _start
_start:        
				MSR		CPSR_c, #0b11010010 			// interrupts masked (off), MODE = IRQ
				LDR		SP, =0x20000           			// set IRQ stack pointer
				
				MSR		CPSR_c, #0b11010011			// interrupts masked, MODE = Supervisor (SVC)								
				LDR		SP, =0x40000				// set supervisor mode (SVC) stack 

                BL       CONFIG_GIC              // configure the ARM generic interrupt controller

				// enable interrupts from parallel port - write to the pushbutton KEY interrupt mask register
				LDR		R0, =KEY_BASE				// pushbutton KEY base address
				MOV		R1, #0xF				// set interrupt mask bits
				STR		R1, [R0, #0x8]				// interrupt mask register is (base + 8)

				// enable IRQ interrupts in the processor
				MSR		CPSR_c, #0b01010011			// IRQ unmasked (enabled), MODE = SVC
IDLE:
                B        IDLE                    // main program simply idles

IRQ_HANDLER:
                PUSH     {R0-R7, LR}
    
                /* Read the ICCIAR in the CPU interface */
                LDR      R4, =0xFFFEC100
                LDR      R5, [R4, #0x0C]         // read the interrupt ID

CHECK_KEYS:
                CMP      R5, #73
UNEXPECTED:     BNE      UNEXPECTED              // if not recognized, stop here
    
                BL       KEY_ISR
EXIT_IRQ:
                /* Write to the End of Interrupt Register (ICCEOIR) */
                STR      R5, [R4, #0x10]
    
                POP      {R0-R7, LR}
                SUBS     PC, LR, #4

/*****************************************************0xFF200050***********************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine checks which KEY(s) have been pressed. It writes to HEX3-0
 ***************************************************************************************/
                .global  KEY_ISR
KEY_ISR:		
				PUSH    {R0-R9, LR}
				LDR		R0, =KEY_BASE
				LDR		R1,	=HEX_BASE_0TO3 
				MOV		R8, #0
				LDR		R2, [R0, #0XC]
				BL		KEY_0
				BL		KEY_1
				BL		KEY_2
				BL		KEY_3
				STR		R9, [R1]
				POP     {R0-R9, LR}
                MOV      PC, LR
				
KEY_0:			
				ANDS	R2, #KEY0
				MOV		R4, #1
				STR		R4, [R0, #0XC]
				MOVEQ	PC, LR
				MOV		R4, #0B0111111
				MOV		R5, #0XFFFFFF00
				LDR		R9, [R1]
				ANDS	R7, R4, R9
				ORREQ	R8, R4
				CMP		R7, #0
				ANDNE	R8, R5
				AND		R9, R5
				ORR		R9, R8
				
				MOV		PC, LR
				
KEY_1:			LDR		R2, [R0, #0XC]
				ANDS	R2, #KEY1
				MOV		R4, #2
				STR		R4, [R0, #0XC]
				MOVEQ	PC, LR
				MOV		R4, #0B0000110
				LSL		R4, #8
				MOV		R5, #0XFFFF00FF
				LDR		R9, [R1]
				ANDS	R7, R4, R9
				ORREQ	R8, R4
				CMP		R7, #0
				ANDNE	R8, R5
				AND		R9, R5
				ORR		R9, R8
				
				MOV		PC, LR

KEY_2:			LDR		R2, [R0, #0XC]
				ANDS	R2, #KEY2
				MOV		R4, #4
				STR		R4, [R0, #0XC]
				MOVEQ	PC, LR
				MOV		R4, #0B1011011
				LSL		R4, #16
				MOV		R5, #0xFF00FFFF
				LDR		R9, [R1]
				ANDS	R7, R4, R9
				ORREQ	R8, R4
				CMP		R7, #0
				ANDNE	R8, R5
				MOV		R2, #4
				STR		R2, [R0, #0XC]
				AND		R9, R5
				ORR		R9, R8
				
				MOV		PC, LR
				
KEY_3:			LDR		R2, [R0, #0XC]
				ANDS	R2, #KEY3
				MOV		R4, #8
				STR		R4, [R0, #0XC]
				MOVEQ	PC, LR
				MOV		R4, #0B1001111
				LSL		R4, #24
				MOV		R5, #0X00FFFFFF
				LDR		R9, [R1]
				ANDS	R7, R4, R9
				ORREQ	R8, R4
				CMP		R7, #0
				ANDNE	R8, R5
				MOV		R2, #8
				STR		R2, [R0, #0XC]
				AND		R9, R5
				ORR		R9, R8
				
				MOV		PC, LR
				

/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
                /* Enable the KEYs interrupts */
                MOV      R0, #73
                MOV      R1, #CPU0
                /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
                BL       CONFIG_INTERRUPT

                /* configure the GIC CPU interface */
                LDR      R0, =0xFFFEC100        // base address of CPU interface
                /* Set Interrupt Priority Mask Register (ICCPMR) */
                LDR      R1, =0xFFFF            // enable interrupts of all priorities levels
                STR      R1, [R0, #0x04]
                /* Set the enable bit in the CPU Interface Control Register (ICCICR). This bit
                 * allows interrupts to be forwarded to the CPU(s) */
                MOV      R1, #1
                STR      R1, [R0]
    
                /* Set the enable bit in the Distributor Control Register (ICDDCR). This bit
                 * allows the distributor to forward interrupts to the CPU interface(s) */
                LDR      R0, =0xFFFED000
                STR      R1, [R0]    
    
                POP      {PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
*/
CONFIG_INTERRUPT:
                PUSH     {R4-R5, LR}
    
                /* Configure Interrupt Set-Enable Registers (ICDISERn). 
                 * reg_offset = (integer_div(N / 32) * 4
                 * value = 1 << (N mod 32) */
                LSR      R4, R0, #3               // calculate reg_offset
                BIC      R4, R4, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED100
                ADD      R4, R2, R4               // R4 = address of ICDISER
    
                AND      R2, R0, #0x1F            // N mod 32
                MOV      R5, #1                   // enable
                LSL      R2, R5, R2               // R2 = value

                /* now that we have the register address (R4) and value (R2), we need to set the
                 * correct bit in the GIC register */
                LDR      R3, [R4]                 // read current register value
                ORR      R3, R3, R2               // set the enable bit
                STR      R3, [R4]                 // store the new register value

                /* Configure Interrupt Processor Targets Register (ICDIPTRn)
                  * reg_offset = integer_div(N / 4) * 4
                  * index = N mod 4 */
                BIC      R4, R0, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED800
                ADD      R4, R2, R4               // R4 = word address of ICDIPTR
                AND      R2, R0, #0x3             // N mod 4
                ADD      R4, R2, R4               // R4 = byte address in ICDIPTR

                /* now that we have the register address (R4) and value (R2), write to (only)
                 * the appropriate byte */
                STRB     R1, [R4]
    
                POP      {R4-R5, PC}

                .end   