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
        Schema::create('product_stock', function (Blueprint $table) {
            $table->id();

            $table->foreignId('product_id')
                ->constrained('products')
                ->cascadeOnUpdate()
                ->cascadeOnDelete();

            $table->foreignId('stock_id')
                ->constrained('stocks')
                ->cascadeOnUpdate()
                ->restrictOnDelete();

            $table->unsignedInteger('qty')->default(0);
            $table->boolean('active')->default(true);

            $table->timestamps();

            $table->unique(['product_id', 'stock_id']);
            $table->index(['product_id', 'active']);
            $table->index(['stock_id', 'active']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('product_stock');
    }
};
