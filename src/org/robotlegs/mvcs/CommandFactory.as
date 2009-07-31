package org.robotlegs.mvcs
{
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.utils.Dictionary;
	
	import org.as3commons.logging.ILogger;
	import org.as3commons.logging.impl.NullLogger;
	import org.robotlegs.core.ICommand;
	import org.robotlegs.core.ICommandFactory;
	import org.robotlegs.core.IEventBroadcaster;
	import org.robotlegs.core.IInjector;
	import org.robotlegs.core.IReflector;
	import org.robotlegs.utils.createDelegate;

	public class CommandFactory implements ICommandFactory
	{
		protected var eventDispatcher:IEventDispatcher;
		protected var eventBroadcaster:IEventBroadcaster;
		protected var injector:IInjector;
		protected var logger:ILogger;
		protected var reflector:IReflector;
		protected var typeToCallbackMap:Dictionary;
		
		/**
		 * Default MVCS <code>ICommandFactory</code> implementation
		 * @param eventDispatcher The <code>IEventDispatcher</code> to listen to
		 * @param injector An <code>IInjector</code> to use for this context
		 * @param reflector An <code>IReflector</code> to use for this context
		 */
		public function CommandFactory(eventDispatcher:IEventDispatcher, injector:IInjector, reflector:IReflector, logger:ILogger = null)
		{
			this.eventDispatcher = eventDispatcher;
			this.injector = injector;
			this.logger = logger ? logger : new NullLogger();
			this.reflector = reflector;
			this.eventBroadcaster = new EventBroadcaster(eventDispatcher);
			this.typeToCallbackMap = new Dictionary(false);
		}
		
		/**
		 * @inheritDoc
		 */
		public function mapCommand(type:String, commandClass:Class, oneshot:Boolean = false):void
		{
			var message:String;
			if (reflector.classExtendsOrImplements(commandClass, ICommand) == false)
			{
				message = ContextError.E_MAP_COM_IMPL + ' - ' + commandClass;
				logger.error(message);
				throw new ContextError(message);
			}
			var callbackMap:Dictionary = typeToCallbackMap[type];
			if (callbackMap == null)
			{
				callbackMap = new Dictionary(false);
				typeToCallbackMap[type] = callbackMap;
			}
			if (callbackMap[commandClass] != null)
			{
				message = ContextError.E_MAP_COM_OVR + ' - type (' + type + ') and Command (' + commandClass + ')';
				logger.error(message);
				throw new ContextError(message);
			}
			var callback:Function = createDelegate(handleEvent, commandClass, oneshot);
			eventDispatcher.addEventListener(type, callback, false, 0, true);
			callbackMap[commandClass] = callback;
		}
		
		/**
		 * @inheritDoc
		 */
		public function unmapCommand(type:String, commandClass:Class):void
		{
			var callbackMap:Dictionary = typeToCallbackMap[type];
			if (callbackMap == null)
			{
				logger.warn('Type (' + type + ') was not mapped to commandClass (' + commandClass + ')');
				return;
			}
			var callback:Function = callbackMap[commandClass];
			if (callback == null)
			{
				logger.warn('Type (' + type + ') was not mapped to commandClass (' + commandClass + ')');
				return;
			}
			eventDispatcher.removeEventListener(type, callback, false);
			delete callbackMap[commandClass];
			logger.info('Command Class Unmapped: (' + commandClass + ') from event type (' + type + ') on (' + eventDispatcher + ')');
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasCommand(type:String, commandClass:Class):Boolean
		{
			var callbackMap:Dictionary = typeToCallbackMap[type];
			if (callbackMap == null)
			{
				return false;
			}
			return callbackMap[commandClass] != null;
		}
		
		/**
		 * Event Handler
		 * @param event The <code>Event</code>
		 * @param commandClass The <code>ICommand<code> Class to construct and execute
		 * @param oneshot Should this command mapping be removed after execution?
		 */
		protected function handleEvent(event:Event, commandClass:Class, oneshot:Boolean):void
		{
			var command:Object = new commandClass();
			logger.info('Command Constructed: (' + command + ') in response to (' + event + ') on (' + eventDispatcher + ')');
			var eventClass:Class = reflector.getClass(event);
			injector.bindValue(eventClass, event);
			injector.injectInto(command);
			injector.unbind(eventClass);
			command.execute();
			if (oneshot)
			{
				unmapCommand(event.type, commandClass);
			}
		}
	
	}
}