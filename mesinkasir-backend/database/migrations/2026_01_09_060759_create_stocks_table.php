<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('stocks', function (Blueprint $table) {
            $table->id();
            $table->string('name', 80)->unique();

            $table->unsignedInteger('qty')->default(0);
            $table->unsignedInteger('buy_price')->default(0);

            $table->boolean('active')->default(true);
            $table->timestamps();

            $table->index(['active']);
        });
    }
    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('stocks');
    }
};
