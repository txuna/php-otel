<?php

use OpenTelemetry\API\Instrumentation\CachedInstrumentation;
use OpenTelemetry\API\Trace\Span;
use OpenTelemetry\API\Trace\StatusCode;
use OpenTelemetry\Context\Context;

require __DIR__ . '/vendor/autoload.php';

OpenTelemetry\Instrumentation\hook(
    class: DemoClass::class,
    function: 'run',
    pre: Telemetry::preHook(...),
    post: Telemetry::postHook(...),
);

class Telemetry {
    static public function preHook(DemoClass $demo, array $params, string $class, string $function, ?string $filename, ?int $lineno) 
    {
        static $instrumentation;
        $instrumentation ??= new CachedInstrumentation('example');
        $span = $instrumentation->tracer()->spanBuilder('democlass-run')->startSpan();
        Context::storage()->attach($span->storeInContext(Context::getCurrent()));

        echo $class . "\n";
        echo $function . "\n";
    }

    static public function postHook (DemoClass $demo, array $params, $returnValue, ?Throwable $exception) 
    {
        $scope = Context::storage()->scope();
        if (null === $scope) {
            return;
        }
        $scope->detach();
        $span = Span::fromContext($scope->context());
        if ($exception) {
            $span->recordException($exception);
            $span->setStatus(StatusCode::STATUS_ERROR);
        }
        $span->end();
    }
}

