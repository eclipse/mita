package org.eclipse.mita.platform.arduinouno.platform

import org.eclipse.mita.program.generator.IPlatformTimeGenerator
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import com.google.inject.Inject
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.GeneratorUtils

class TimeGenerator implements IPlatformTimeGenerator {

	@Inject
	protected extension CodeFragmentProvider codeFragmentProvider

	@Inject
	protected IPlatformEventLoopGenerator eventLoopGenerator

	@Inject
	protected extension GeneratorUtils

	override generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler) {
		return codeFragmentProvider.create('''Timer_Enable();''')
	}

	override generateTimeGoLive(CompilationContext context) {
		return CodeFragment.EMPTY
	}

	override generateTimeSetup(CompilationContext context) {
		val allTimeEvents = context.allTimeEvents

		val body = codeFragmentProvider.create('''
			Retcode_T result = NO_EXCEPTION;
			
			result = Timer_Connect();
			if(result != NO_EXCEPTION)
			{
				return result;
			}
		''')

		return codeFragmentProvider.create(body).setPreamble('''
			«FOR handler : allTimeEvents»
				«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
				static uint32_t count_«period» = 0;
				bool get«handler.handlerName»_flag(){
					return «handler.handlerName»_flag;
				}
				
				void set«handler.handlerName»_flag(bool val){
					«handler.handlerName»_flag = val;
				}
			«ENDFOR»

			
			Retcode_T Tick_Timer(void)
			{
			«FOR handler : allTimeEvents»
				«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
					count_«period»++;
					if(count_«period» % «period» == 0)
					{
						count_«period» = 0;
						«handler.handlerName»_flag = true;
					}
				
			«ENDFOR»			
				return NO_EXCEPTION;
			}
		''')
		.addHeader('MitaExceptions.h', false)
		.addHeader('MitaEvents.h', false)
		.addHeader('MitaTime.h', false)
		.addHeader('ARD_Timer.h', false)
	}

	protected def allTimeEvents(CompilationContext context) {
		return context.allEventHandlers.filter[x|x.event instanceof TimeIntervalEvent]
	}

}
