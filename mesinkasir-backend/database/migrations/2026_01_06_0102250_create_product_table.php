<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();

            $table->foreignId('category_id')
                ->constrained('product_categories')
                ->cascadeOnUpdate()
                ->restrictOnDelete();

            $table->string('name', 120);
            $table->unsignedInteger('price');
            $table->unsignedInteger('qty')->default(0);
            $table->boolean('active')->default(true);

            $table->timestamps();

            $table->index(['category_id', 'active']);
        });
    }
    
    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
